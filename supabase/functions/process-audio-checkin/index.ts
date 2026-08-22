// ==================================================
// PROCESS-AUDIO-CHECKIN — Supabase Edge Function
//
// Replaces Firebase processAudioCheckIn.
// Pipeline: Storage → Gemini multimodal → daily_logs + tasks
//
// Preserves EXACT Step 4 safety prompt, deterministic
// status logic, and task extraction from Firebase.
// ==================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

interface ProcessAudioPayload {
  circle_id: string;
  audio_path: string;
}

interface GeminiExtraction {
  sentiment: 'positive' | 'neutral' | 'negative' | 'unclear';
  medicationStatus: 'taken' | 'not_taken' | 'not_mentioned' | 'unclear';
  medicationsMentioned: string[];
  flaggedConcerns: string[];
  taskResponses: Array<{
    taskId: string;
    response: string;
    status: 'answered' | 'unanswered';
  }>;
  confidenceScore: number;
  summary: string;
}

// ── Deterministic status (exact copy from Firebase Step 4) ──
function computeStatus(flaggedConcerns: string[]): string {
  if (!flaggedConcerns || flaggedConcerns.length === 0) return 'green';

  const redRegex = /\b(severe pain|need help|call me immediately|emergency|urgent|immediate help|help right now)\b/i;
  for (const concern of flaggedConcerns) {
    if (redRegex.test(concern)) return 'red';
  }
  return 'yellow';
}

// ── Map medication enum → boolean|null ──
function mapMedicationTaken(status: string): boolean | null {
  if (status === 'taken') return true;
  if (status === 'not_taken') return false;
  return null;
}

Deno.serve(async (req: Request) => {
  // ── CORS preflight ──
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ success: false, error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  try {
    // ── 1. Authenticate caller ──
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid or expired token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 2. Parse & validate payload ──
    let body: ProcessAudioPayload;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid JSON body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!body.circle_id || typeof body.circle_id !== 'string') {
      return new Response(
        JSON.stringify({ success: false, error: 'circle_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!body.audio_path || typeof body.audio_path !== 'string') {
      return new Response(
        JSON.stringify({ success: false, error: 'audio_path is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Validate audio path belongs to this circle and user
    const expectedPrefix = `${body.circle_id}/${user.id}/`;
    if (!body.audio_path.startsWith(expectedPrefix)) {
      return new Response(
        JSON.stringify({ success: false, error: 'Audio path does not match circle or user' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 3. Verify caller is circle member ──
    const adminClient = createAdminClient();

    const { data: membership, error: memberError } = await adminClient
      .from('circle_members')
      .select('role')
      .eq('circle_id', body.circle_id)
      .eq('user_id', user.id)
      .single();

    if (memberError || !membership) {
      return new Response(
        JSON.stringify({ success: false, error: 'You are not a member of this circle' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 4. Idempotency check ──
    const { data: existingLog } = await adminClient
      .from('daily_logs')
      .select('id')
      .eq('audio_url', body.audio_path)
      .maybeSingle();

    if (existingLog) {
      return new Response(
        JSON.stringify({ success: true, log_id: existingLog.id, cached: true }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 5. Download audio from Supabase Storage ──
    const { data: audioData, error: downloadError } = await adminClient
      .storage
      .from('audio_inbox')
      .download(body.audio_path);

    if (downloadError || !audioData) {
      console.error('Storage download failed:', downloadError);
      return new Response(
        JSON.stringify({ success: false, error: 'Audio file not found in storage' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 6. Fetch pending tasks for context ──
    const { data: pendingTasks } = await adminClient
      .from('tasks')
      .select('id, text')
      .eq('circle_id', body.circle_id)
      .eq('status', 'pending');

    const tasksForPrompt = (pendingTasks || []).map(t => ({
      taskId: t.id,
      text: t.text,
    }));

    // ── 7. Call Gemini multimodal API ──
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiApiKey) {
      return new Response(
        JSON.stringify({ success: false, error: 'AI processing not configured' }),
        { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Convert audio to base64 for Gemini inline_data
    const audioBytes = new Uint8Array(await audioData.arrayBuffer());
    const base64Audio = btoa(String.fromCharCode(...audioBytes));

    // Determine MIME type from path extension
    const ext = body.audio_path.split('.').pop()?.toLowerCase() ?? 'm4a';
    const mimeMap: Record<string, string> = {
      m4a: 'audio/mp4',
      mp4: 'audio/mp4',
      mp3: 'audio/mpeg',
      mpeg: 'audio/mpeg',
      wav: 'audio/wav',
    };
    const mimeType = mimeMap[ext] ?? 'audio/mp4';

    // Exact safety prompt from Firebase Step 4
    const prompt = `You are a literal data extractor. You are expressly forbidden from acting as a doctor, diagnosing, recommending treatment, inferring a disease, or offering medical advice.
Your job is ONLY to extract facts explicitly stated in the provided audio.
If information is not mentioned or is unclear, return "not_mentioned" or "unclear". Never guess.
Do not infer a medication was taken when it was not stated.
Do not infer a symptom that was not stated.
Do not infer severity that was not explicitly communicated.
Do not invent missing information.
Write a short factual summary using ONLY information explicitly stated in the audio. Do not interpret, diagnose, assess medical severity, infer unstated facts, or provide advice. If information is unclear, state that it is unclear.

For Pending Tasks:
If the elder explicitly answers a task in the audio, set status to "answered" and extract the response.
If the elder ignores the task, talks about something else, or the answer is unclear, set status to "unanswered". Do not guess or infer task completion.

Respond with JSON matching this exact schema:
{
  "sentiment": "positive" | "neutral" | "negative" | "unclear",
  "medicationStatus": "taken" | "not_taken" | "not_mentioned" | "unclear",
  "medicationsMentioned": [],
  "flaggedConcerns": [],
  "taskResponses": [{ "taskId": "", "response": "", "status": "answered" | "unanswered" }],
  "confidenceScore": 0.0,
  "summary": ""
}

Pending Tasks: ${JSON.stringify(tasksForPrompt)}`;

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`;

    let llmResult: GeminiExtraction;
    try {
      const geminiResponse = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              {
                inline_data: {
                  mime_type: mimeType,
                  data: base64Audio,
                },
              },
              { text: prompt },
            ],
          }],
          generationConfig: {
            responseMimeType: 'application/json',
          },
        }),
      });

      if (!geminiResponse.ok) {
        const errText = await geminiResponse.text();
        console.error('Gemini API error:', geminiResponse.status, errText);

        if (geminiResponse.status === 429) {
          return new Response(
            JSON.stringify({ success: false, error: 'AI processing temporarily unavailable. Please try again later.' }),
            { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
          );
        }

        return new Response(
          JSON.stringify({ success: false, error: 'AI processing temporarily unavailable' }),
          { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      const geminiJson = await geminiResponse.json();
      const text = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) {
        throw new Error('Empty Gemini response');
      }
      llmResult = JSON.parse(text);
    } catch (err) {
      console.error('Gemini processing failed:', err);
      return new Response(
        JSON.stringify({ success: false, error: 'AI processing temporarily unavailable' }),
        { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 8. Compute deterministic status ──
    const status = computeStatus(llmResult.flaggedConcerns);
    const medicationTaken = mapMedicationTaken(llmResult.medicationStatus);
    const today = new Date().toISOString().split('T')[0];

    // ── 9. Insert daily_log ──
    const { data: logData, error: logError } = await adminClient
      .from('daily_logs')
      .insert({
        circle_id: body.circle_id,
        date: today,
        status: status,
        transcript: llmResult.summary, // Gemini extracted from audio directly
        summary: llmResult.summary,
        medication_taken: medicationTaken,
        flagged_concerns: llmResult.flaggedConcerns ?? [],
        responded_at: new Date().toISOString(),
        audio_url: body.audio_path,
        provenance: {
          sourceChannel: 'elder_view_app',
          processingEngine: 'gemini-2.0-flash',
          sttEngine: 'gemini-multimodal',
          medicationStatusRich: llmResult.medicationStatus,
          taskResponses: llmResult.taskResponses,
          confidenceScore: llmResult.confidenceScore,
          sentiment: llmResult.sentiment,
        },
      })
      .select('id')
      .single();

    if (logError || !logData) {
      console.error('Daily log insert failed:', logError);
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to save check-in record' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 10. Process task responses ──
    if (pendingTasks && pendingTasks.length > 0 && llmResult.taskResponses) {
      for (const pendingTask of pendingTasks) {
        const extracted = llmResult.taskResponses.find(
          (tr) => tr.taskId === pendingTask.id,
        );

        let newStatus = 'delivered';
        if (extracted && extracted.status === 'answered') {
          newStatus = 'acknowledged';
        }

        await adminClient
          .from('tasks')
          .update({
            status: newStatus,
            delivered_in_checkin_date: today,
          })
          .eq('id', pendingTask.id)
          .eq('status', 'pending'); // guard: don't downgrade
      }
    }

    // ── 11. Success ──
    return new Response(
      JSON.stringify({
        success: true,
        log_id: logData.id,
        status: status,
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Unhandled error in process-audio-checkin:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
