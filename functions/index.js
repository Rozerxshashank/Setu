const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { SpeechClient } = require('@google-cloud/speech');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { DateTime } = require('luxon');

admin.initializeApp();
const db = admin.firestore();

const speechClient = new SpeechClient();
// Initialize GenAI with a stub key for now. Real deployment uses Secret Manager.
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'stub_key');

// ---------------------------------------------------------------------------
// PHASE 1: Server-Owned Authorization & Invites
// ---------------------------------------------------------------------------

exports.createCircle = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in.");
  }

  const { elderName, elderPhoneNumber, preferredLanguage, checkInTime, timezone, interactionChannel } = request.data;
  if (!elderName || !elderPhoneNumber || !preferredLanguage) {
    throw new HttpsError("invalid-argument", "Missing required circle fields.");
  }

  const circleRef = db.collection("familyCircles").doc();
  const userId = request.auth.uid;
  
  // Fetch user profile to get their name
  const userDoc = await db.collection("users").doc(userId).get();
  const userName = userDoc.exists ? userDoc.data().name : "Unknown User";

  const newCircle = {
    circleId: circleRef.id,
    elderName,
    elderPhoneNumber,
    preferredLanguage,
    checkInTime: checkInTime || "09:00",
    timezone: timezone || "Asia/Kolkata",
    interactionChannel: interactionChannel || "whatsapp",
    members: [{
      userId: userId,
      name: userName,
      role: "primary"
    }],
    memberIds: [userId],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    consentGranted: false, // Must be explicitly granted later
  };

  await circleRef.set(newCircle);
  
  // Update user's circleIds
  if (userDoc.exists) {
    await db.collection("users").doc(userId).update({
      circleIds: admin.firestore.FieldValue.arrayUnion(circleRef.id)
    });
  }

  return { circleId: circleRef.id };
});

exports.createInvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in.");
  }

  const { circleId, role } = request.data;
  if (!circleId) {
    throw new HttpsError("invalid-argument", "Missing circleId.");
  }

  const circleDoc = await db.collection("familyCircles").doc(circleId).get();
  if (!circleDoc.exists) {
    throw new HttpsError("not-found", "Circle not found.");
  }

  const circleData = circleDoc.data();
  if (!circleData.memberIds.includes(request.auth.uid)) {
    throw new HttpsError("permission-denied", "Only members can create invites.");
  }

  const callerMember = circleData.members.find(m => m.userId === request.auth.uid);
  if (callerMember.role !== "primary") {
    throw new HttpsError("permission-denied", "Only primary members can create invites.");
  }

  const inviteRef = db.collection("invites").doc();
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 7); // 7 days expiry

  await inviteRef.set({
    inviteId: inviteRef.id,
    circleId: circleId,
    createdBy: request.auth.uid,
    role: role || "sibling",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    status: "active" // active, redeemed, revoked
  });

  return { inviteId: inviteRef.id };
});

exports.joinCircle = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in.");
  }

  const { inviteId } = request.data;
  if (!inviteId) {
    throw new HttpsError("invalid-argument", "Missing inviteId.");
  }

  const inviteRef = db.collection("invites").doc(inviteId);
  
  // Use a transaction to ensure invite is only redeemed once
  return await db.runTransaction(async (transaction) => {
    const inviteDoc = await transaction.get(inviteRef);
    if (!inviteDoc.exists) {
      throw new HttpsError("not-found", "Invite not found.");
    }

    const inviteData = inviteDoc.data();
    if (inviteData.status !== "active") {
      throw new HttpsError("failed-precondition", "Invite is no longer active.");
    }
    
    if (inviteData.expiresAt.toDate() < new Date()) {
      throw new HttpsError("failed-precondition", "Invite has expired.");
    }

    const circleRef = db.collection("familyCircles").doc(inviteData.circleId);
    const circleDoc = await transaction.get(circleRef);
    
    if (!circleDoc.exists) {
      throw new HttpsError("not-found", "Target circle no longer exists.");
    }

    const circleData = circleDoc.data();
    const userId = request.auth.uid;
    
    if (circleData.memberIds.includes(userId)) {
      throw new HttpsError("already-exists", "You are already a member of this circle.");
    }

    const userRef = db.collection("users").doc(userId);
    const userDoc = await transaction.get(userRef);
    const userName = userDoc.exists ? userDoc.data().name : "Unknown User";

    const newMember = {
      userId: userId,
      name: userName,
      role: inviteData.role
    };

    transaction.update(inviteRef, { 
      status: "redeemed",
      redeemedBy: userId,
      redeemedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    transaction.update(circleRef, {
      members: admin.firestore.FieldValue.arrayUnion(newMember),
      memberIds: admin.firestore.FieldValue.arrayUnion(userId)
    });

    if (userDoc.exists) {
      transaction.update(userRef, {
        circleIds: admin.firestore.FieldValue.arrayUnion(inviteData.circleId)
      });
    }

    return { success: true, circleId: inviteData.circleId };
  });
});

// ---------------------------------------------------------------------------
// PHASE 3 & 4: Audio Ingestion, STT & LLM Processing
// ---------------------------------------------------------------------------

exports.processAudioCheckIn = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "User must be logged in.");
  
  const { circleId, storagePath } = request.data;
  if (!circleId || !storagePath) throw new HttpsError("invalid-argument", "Missing required fields.");

  // Validation: Ensure storagePath belongs to this circle and caller
  if (!storagePath.startsWith(`audio_inbox/${circleId}/${request.auth.uid}/`)) {
    throw new HttpsError("permission-denied", "Invalid storage path or unauthorized.");
  }

  // Security check: verify caller is member
  const circleDoc = await db.collection("familyCircles").doc(circleId).get();
  if (!circleDoc.exists || !circleDoc.data().memberIds.includes(request.auth.uid)) {
    throw new HttpsError("permission-denied", "Unauthorized access to this circle.");
  }

  // Idempotency Check
  const fileName = storagePath.split('/').pop();
  const logId = `log_${fileName.replace(/\./g, '_')}`;
  const logRef = db.collection("familyCircles").doc(circleId).collection("dailyLogs").doc(logId);
  
  const existingLog = await logRef.get();
  if (existingLog.exists) {
    return { success: true, logId: logRef.id };
  }

  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);

  const [exists] = await file.exists();
  if (!exists) throw new HttpsError("not-found", "Audio file not found in storage.");
  
  const [metadataObj] = await file.getMetadata();
  if (metadataObj.size > 5 * 1024 * 1024) throw new HttpsError("out-of-range", "File too large.");
  if (!metadataObj.contentType.startsWith("audio/")) throw new HttpsError("invalid-argument", "Not an audio file.");

  // 1. STT call
  let transcript = "";
  try {
    const [response] = await speechClient.recognize({
      config: {
        languageCode: circleDoc.data().preferredLanguage === 'hindi' ? 'hi-IN' : 'en-US',
      },
      audio: {
        uri: `gs://${bucket.name}/${storagePath}`
      }
    });
    transcript = response.results.map(r => r.alternatives[0].transcript).join('\n').trim();
    if (!transcript) throw new Error("Empty transcript");
  } catch (e) {
    throw new HttpsError("internal", "STT processing failed: " + e.message);
  }

  // Fetch pending tasks
  const tasksSnapshot = await db.collection("familyCircles").doc(circleId).collection("tasks").where("status", "==", "pending").get();
  const pendingTasks = tasksSnapshot.docs.map(d => ({ taskId: d.id, text: d.data().text }));

  // 2. LLM call
  const model = genAI.getGenerativeModel({
    model: "gemini-1.5-flash",
    systemInstruction: "You are a literal data extractor. You are expressly forbidden from acting as a doctor, diagnosing, or offering medical advice. You must only extract explicitly stated facts.",
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: {
        type: "object",
        properties: {
          sentiment: { type: "string", enum: ["positive", "neutral", "negative", "unclear"] },
          medicationStatus: { type: "string", enum: ["taken", "not_taken", "not_mentioned", "unclear"] },
          medicationsMentioned: { type: "array", items: { type: "string" } },
          flaggedConcerns: { type: "array", items: { type: "string" } },
          taskResponses: {
             type: "array",
             items: {
                type: "object",
                properties: {
                   taskId: { type: "string" },
                   response: { type: "string" },
                   status: { type: "string", enum: ["answered", "unanswered"] }
                },
                required: ["taskId", "response", "status"]
             }
          },
          confidenceScore: { type: "number" },
          summary: { type: "string" }
        },
        required: ["sentiment", "medicationStatus", "medicationsMentioned", "flaggedConcerns", "taskResponses", "confidenceScore", "summary"]
      }
    }
  });

  const prompt = `
You are a literal data extractor. You are expressly forbidden from acting as a doctor, diagnosing, recommending treatment, inferring a disease, or offering medical advice.
Your job is ONLY to extract facts explicitly stated in the provided transcript.
If information is not mentioned or is unclear, return "not_mentioned" or "unclear". Never guess.
Do not infer a medication was taken when it was not stated.
Do not infer a symptom that was not stated.
Do not infer severity that was not explicitly communicated.
Do not invent missing information.
Write a short factual summary using ONLY information explicitly stated in the transcript. Do not interpret, diagnose, assess medical severity, infer unstated facts, or provide advice. If information is unclear, state that it is unclear.

For Pending Tasks:
If the elder explicitly answers a task in the transcript, set status to "answered" and extract the response.
If the elder ignores the task, talks about something else, or the answer is unclear, set status to "unanswered". Do not guess or infer task completion.

Transcript: "${transcript}"
Pending Tasks: ${JSON.stringify(pendingTasks)}
  `;

  let llmResult;
  try {
     const result = await model.generateContent(prompt);
     llmResult = JSON.parse(result.response.text());
  } catch (e) {
     throw new HttpsError("internal", "LLM processing failed: " + e.message);
  }

  // 3. Deterministic Status logic
  let status = "green";
  if (llmResult.flaggedConcerns && llmResult.flaggedConcerns.length > 0) {
    status = "yellow";
    // Refined RED thresholds using regex to avoid arbitrary substring false positives
    const redRegex = /\b(severe pain|need help|call me immediately|emergency|urgent|immediate help|help right now)\b/i;
    for (const concern of llmResult.flaggedConcerns) {
       if (redRegex.test(concern)) {
          status = "red";
          break;
       }
    }
  }

  // Map medication enum to boolean|null for PRD compatibility
  let medicationTaken = null;
  if (llmResult.medicationStatus === "taken") medicationTaken = true;
  else if (llmResult.medicationStatus === "not_taken") medicationTaken = false;

  const logData = {
    logId: logRef.id,
    date: new Date().toISOString().split('T')[0],
    status: status,
    transcript: transcript,
    summary: llmResult.summary,
    medicationTaken: medicationTaken,
    flaggedConcerns: llmResult.flaggedConcerns,
    respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    audioUrl: storagePath,
    provenance: {
      sourceChannel: "elder_view_app",
      processingEngine: "gemini-1.5-flash",
      sttEngine: "gcp-speech-to-text",
      rawTranscript: transcript,
      medicationStatusRich: llmResult.medicationStatus,
      taskResponses: llmResult.taskResponses
    }
  };

  // 4. Atomic Task & Log Update
  try {
    await db.runTransaction(async (transaction) => {
      const logDoc = await transaction.get(logRef);
      if (logDoc.exists) {
         // ALREADY_EXISTS, another request succeeded
         return; 
      }
      transaction.set(logRef, logData);
      
      // Now process tasks securely
      for (const pendingTask of pendingTasks) {
        const taskRef = db.collection("familyCircles").doc(circleId).collection("tasks").doc(pendingTask.taskId);
        const taskDoc = await transaction.get(taskRef);
        
        if (!taskDoc.exists) continue; // Task deleted or invalid
        if (taskDoc.data().status !== "pending") continue; // Strict concurrency lock, don't downgrade
        
        // Find if LLM explicitly answered it
        const extractedResponse = (llmResult.taskResponses || []).find(tr => tr.taskId === pendingTask.taskId);
        
        let newStatus = "delivered";
        if (extractedResponse && extractedResponse.status === "answered") {
           newStatus = "acknowledged";
        }
        
        transaction.update(taskRef, {
          status: newStatus,
          deliveredInCheckInDate: logData.date
        });
      }
    });
  } catch (e) {
    throw new HttpsError("internal", "Failed to write daily log and tasks: " + e.message);
  }

  return { success: true, logId: logRef.id };
});

exports.whatsappWebhook = onRequest(async (req, res) => {
  // TODO: Validate Twilio/Gupshup Signature using secrets
  // TODO: Download audio from WhatsApp media URL
  // TODO: Upload to Firebase Storage `audio_inbox/${circleId}/whatsapp/${uuid}`
  // TODO: await processAudioPayload({ audioUri: newStorageUri, circleId, metadata: { channel: 'whatsapp' }})
  
  res.status(501).send("WhatsApp webhook scaffold. To be implemented when secrets are configured.");
});

// ---------------------------------------------------------------------------
// PHASE 6: Scheduled Notifications
// ---------------------------------------------------------------------------

exports.checkMissedCheckIns = onSchedule("every 30 minutes", async (event) => {
  console.log("Checking missed checkins");
  const circlesSnapshot = await db.collection("familyCircles").get();
  
  for (const doc of circlesSnapshot.docs) {
    const circle = doc.data();
    const circleId = doc.id;
    const tz = circle.timezone || "Asia/Kolkata";
    
    const nowLocal = DateTime.now().setZone(tz);
    
    // Evaluate today and yesterday
    const datesToEvaluate = [
      nowLocal.toFormat("yyyy-MM-dd"), // Today
      nowLocal.minus({ days: 1 }).toFormat("yyyy-MM-dd") // Yesterday
    ];
    
    for (const dateStr of datesToEvaluate) {
      let scheduledTimeLocal;
      try {
        scheduledTimeLocal = DateTime.fromFormat(`${dateStr} ${circle.checkInTime || '09:00'}`, "yyyy-MM-dd HH:mm", { zone: tz });
      } catch (e) {
        console.warn(`Invalid checkInTime for circle ${circleId}: ${circle.checkInTime}`);
        continue;
      }
      
      // If we are before scheduled time, do nothing for this date
      if (nowLocal < scheduledTimeLocal) {
        continue;
      }
      
      const diffHours = nowLocal.diff(scheduledTimeLocal, 'hours').hours;
      const endOfDay = scheduledTimeLocal.endOf('day'); 
      const stateRef = db.collection("familyCircles").doc(circleId).collection("checkInStates").doc(dateStr);
      const greyLogId = `${circleId}_${dateStr}_missed`;
      const logRef = db.collection("familyCircles").doc(circleId).collection("dailyLogs").doc(greyLogId);
      
      const action = await db.runTransaction(async (transaction) => {
        // 1. Check for real response
        const logsQuery = db.collection("familyCircles")
          .doc(circleId)
          .collection("dailyLogs")
          .where("date", "==", dateStr);
        const logsSnapshot = await transaction.get(logsQuery);
          
        let hasRealResponse = false;
        for (const logDoc of logsSnapshot.docs) {
          if (['green', 'yellow', 'red'].includes(logDoc.data().status)) {
            hasRealResponse = true;
            break;
          }
        }
        
        if (hasRealResponse) {
          transaction.set(stateRef, { date: dateStr, status: 'responded' }, { merge: true });
          return 'responded';
        }
        
        // 2. Check current state
        const stateDoc = await transaction.get(stateRef);
        const stateData = stateDoc.exists ? stateDoc.data() : {
          date: dateStr,
          status: 'pending',
          nudgeSentAt: null,
          greyLogCreated: false,
          finalAlertSentAt: null,
          finalAlertClaimedAt: null
        };
        
        if (stateData.status === 'responded') {
          return 'done';
        }
        
        if (stateData.status === 'missed' && stateData.finalAlertSentAt) {
          return 'done'; // Fully finalized
        }
        
        // 3. Evaluate Nudge
        if (diffHours >= 2.0 && !stateData.nudgeSentAt && nowLocal < endOfDay) {
          transaction.set(stateRef, { date: dateStr, status: 'pending', nudgeSentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
          return 'nudge';
        }
        
        // 4. Evaluate Final Cutoff
        if (nowLocal >= endOfDay) {
          let shouldSendFCM = false;
          
          if (!stateData.greyLogCreated) {
            const logDoc = await transaction.get(logRef);
            if (!logDoc.exists) {
              transaction.set(logRef, {
                date: dateStr,
                status: "grey",
                transcript: "",
                summary: "No check-in received.",
                medicationTaken: null,
                flaggedConcerns: [],
                respondedAt: null,
                audioUrl: null
              });
            }
            transaction.set(stateRef, { date: dateStr, status: 'missed', greyLogCreated: true }, { merge: true });
          }
          
          if (!stateData.finalAlertSentAt) {
            if (stateData.finalAlertClaimedAt) {
              // Retry mechanism: if claimed more than 10 minutes ago, retry
              const claimedAt = stateData.finalAlertClaimedAt.toDate ? stateData.finalAlertClaimedAt.toDate() : new Date(stateData.finalAlertClaimedAt);
              if ((new Date() - claimedAt) > 10 * 60 * 1000) {
                shouldSendFCM = true;
              }
            } else {
              shouldSendFCM = true;
            }
          }
          
          if (shouldSendFCM) {
             transaction.set(stateRef, { finalAlertClaimedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
             return 'final_alert';
          }
        }
        
        return 'none';
      });
      
      // Process side effects safely outside transaction
      if (action === 'nudge') {
        console.log(`[Demo Mode] Elder check-in nudge simulated for ${circleId} — no external message sent.`);
      } else if (action === 'final_alert') {
        if (circle.memberIds && circle.memberIds.length > 0) {
          let fcmTokens = [];
          for (const memberId of circle.memberIds) {
            const userDoc = await db.collection("users").doc(memberId).get();
            if (userDoc.exists && userDoc.data().fcmTokens) {
              fcmTokens.push(...userDoc.data().fcmTokens);
            }
          }
          
          if (fcmTokens.length > 0) {
            const message = {
              notification: {
                title: "Setu Check-In",
                body: `No check-in from ${circle.elderName} today. Consider calling to check in.`
              },
              tokens: fcmTokens
            };
            try {
              await admin.messaging().sendEachForMulticast(message);
              // Safely mark success
              await stateRef.set({ finalAlertSentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
            } catch (err) {
              console.error(`FCM error for circle ${circleId}:`, err);
            }
          } else {
             // No tokens, mark sent
             await stateRef.set({ finalAlertSentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
          }
        } else {
           // No members, mark sent
           await stateRef.set({ finalAlertSentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        }
      }
    }
  }
});
