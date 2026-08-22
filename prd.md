# Product Requirements Document: Setu (Eldercare Companion App)

**Version:** 1.0
**Status:** Draft for Development
**Target Build Tool:** Antigravity (AI code generation)
**Review Process:** GPT/Codex code review against this PRD
**Platform:** Flutter (iOS + Android), Firebase backend

---

## 1. Product Summary

Setu ("bridge" in Hindi) is a two-sided app that closes the daily-awareness gap between adult children living away from home and their elderly parents living alone or semi-independently. It replaces the unreliable "I'll call them today" habit with a lightweight, low-effort daily check-in system that respects the elder's comfort level with technology, gives adult children (often multiple siblings) a shared, trackable view of their parent's wellbeing, and surfaces concerning patterns before they become emergencies.

**Core insight driving the design:** Elderly parents will not learn a new, complex app. The parent-facing experience must feel like receiving a phone call or a WhatsApp voice note from family — not like operating software. All complexity (settings, scheduling, multi-child coordination, history, alerts) lives on the child's side.

---

## 2. Problem Statement

- Adult children living away from aging parents want daily reassurance that their parent is okay, but sustaining a genuine daily phone call is difficult to maintain long-term due to work schedules, time zones, and simple human forgetfulness.
- When multiple siblings share caregiving responsibility, there is no shared source of truth — each assumes someone else has checked in, and gaps go unnoticed ("bystander effect" in families).
- A single phone call produces an impression, not a record. Recurring symptoms (pain, missed medication, mood changes) go unnoticed because there is no history to look back on.
- Existing solutions fail Indian households specifically:
  - Western fall-detection wearables assume the primary risk is a fall; the more common risk is a slow-building, missed pattern (missed medicine, worsening pain, low mood).
  - Consumer eldercare apps require the elder to operate an app UI, which is a non-starter for most elderly users.
  - Generic reminder/calendar apps don't handle the two-sided nature of this problem (elder input + family visibility + escalation).

---

## 3. Goals and Non-Goals

### Goals (v1 / Hackathon MVP)
1. Let an elder respond to a daily check-in with zero learning curve (voice-based, single action).
2. Let a child (or multiple children) view a simple daily status feed with clear visual flags (ok / attention / missed).
3. Automatically summarize the elder's voice response into a short, readable update.
4. Alert the family if a check-in is missed by a set time.
5. Let a child add simple reminders/tasks that get delivered to the elder during their next check-in.

### Non-Goals (explicitly out of scope for v1)
- This is **not** a medical diagnostic tool. It does not detect falls, analyze vital signs, or make health claims.
- It does not replace emergency services or medical alert systems (e.g., panic buttons).
- It does not attempt full EHR/medical record integration in v1.
- It does not support real-time video calling (voice-note/call-based interaction only).
- It does not handle billing/subscription/payment infrastructure in v1 — assume free/hackathon-demo mode.

---

## 4. Users and Personas

### Persona 1: The Elder ("Amma/Appa")
- Age 60–80, lives alone or with a part-time helper, in a tier-1/2/3 Indian city or town.
- Comfortable with basic phone calls and possibly WhatsApp voice notes; not comfortable with app navigation, typing, or multi-step UI.
- Primary language may not be English.
- Motivation: wants to reassure their children, does not want to feel "monitored" or infantilized.

### Persona 2: The Adult Child ("Caregiver")
- Age 28–45, lives in a different city or country from their parent.
- Often shares caregiving responsibility with 1–2 siblings.
- Busy professional; wants reassurance without needing to remember to check in manually every day.
- Motivation: peace of mind, early warning of problems, shared visibility with siblings so responsibility doesn't silently fall on one person.

### Persona 3: The Secondary Caregiver (Sibling)
- Same profile as Persona 2, but joins an existing family group rather than creating it.
- Needs the same visibility without needing to set anything up.

---

## 5. Core User Flows

### 5.1 Onboarding (Child-driven, elder does nothing)
1. Child downloads the Flutter app, creates an account (Firebase Auth — phone number OTP, since this is the norm in India).
2. Child creates a "Family Circle" and adds their parent's phone number.
3. Child sets:
   - Preferred check-in time (e.g., 9:00 AM daily)
   - Parent's preferred language
   - Parent's interaction channel: **WhatsApp voice note** (primary, recommended) or **automated phone call** (fallback/stretch)
   - Optional: known medications/reminders to include in check-ins
4. Child invites siblings via a shareable link/code to join the same Family Circle (all siblings see the same dashboard).
5. System sends a one-time explanatory message to the parent's WhatsApp (in their language) introducing the daily check-in, sent by the system but framed as "from [Child's name]."

### 5.2 Daily Check-In (Elder side)
1. At the scheduled time, the elder receives a WhatsApp message (via WhatsApp Business API) with:
   - A short spoken/text prompt in their language (e.g., "How are you feeling today? Any pain? Did you take your morning medicine?")
   - Any pending reminder from a child, appended to the same message (e.g., "Also — Priya wants to know if the electricity bill was paid.")
2. Elder replies with a **voice note** (their natural behavior on WhatsApp already — no new skill required).
3. If no response by a configurable cutoff (e.g., 2 hours after scheduled time), a gentle follow-up nudge is sent once. If still no response by end of day, the family is alerted (see 5.4).

### 5.3 Processing Pipeline (Backend)
1. Incoming voice note is received via WhatsApp Business API webhook.
2. Audio is transcribed via a speech-to-text service (supporting Indian languages).
3. Transcript is sent to an LLM with a structured prompt to extract:
   - Overall sentiment/mood (positive / neutral / concerning)
   - Medication taken (yes / no / not mentioned)
   - Any flagged symptoms or concerns (free text, e.g., "mentioned knee pain")
   - Any responses to pending reminders (e.g., "confirmed bill paid")
4. Output is stored as a structured daily log entry, linked to the Family Circle.
5. A status color is computed: **Green** (all good), **Yellow** (mentioned a minor concern), **Red** (explicit distress signal, e.g., words indicating pain, illness, or a direct request for help) or **Grey** (missed check-in).

### 5.4 Family Dashboard (Child side, Flutter app)
1. Home screen: a simple daily feed, one card per day, showing date, status color, and a one-line AI-generated summary.
2. Tapping a card expands to show the full transcript (optional, for transparency/trust) and any flagged items.
3. If a check-in is missed past the cutoff, all members of the Family Circle receive a push notification: "No check-in from Appa today."
4. Any child can add a task/reminder from the dashboard, which gets included in the next day's check-in prompt.
5. A simple trends view (stretch goal): shows frequency of flagged concerns over the past 2–4 weeks (e.g., "knee pain mentioned 3 times this month") to help spot patterns worth raising with a doctor.

### 5.5 Escalation Flow
1. If a check-in is classified **Red**, immediately push a high-priority notification to all Family Circle members, bypassing normal digest batching.
2. Red classification does not auto-contact emergency services — it surfaces urgency to the family, who decide next steps. The app should never claim to be a substitute for emergency response.

---

## 6. Feature List (Prioritized)

### P0 — Must have for hackathon demo
- Family Circle creation + multi-member join
- Scheduled WhatsApp check-in prompt (can be simulated/triggered manually for demo if WhatsApp Business API approval is a blocker — see Section 10)
- Voice note → transcript → LLM summary pipeline
- Daily feed dashboard with status colors
- Missed check-in alert
- Task/reminder injection into next check-in

### P1 — Strong stretch goals if time allows
- Multi-language support beyond one demo language
- Trends/pattern view across multiple days
- Automated phone call fallback (via Twilio/Exotel) for elders who don't use WhatsApp
- Transcript trust view (raw transcript alongside AI summary, for transparency)

### P2 — Post-hackathon roadmap (mention in pitch, don't build)
- Doctor-shareable weekly PDF summary
- Integration with local pharmacy/medicine delivery reminders
- Support for a paid caregiver/helper as an additional circle member
- On-device/offline transcript caching for low-connectivity areas

---

## 7. System Architecture

```
┌─────────────────┐          ┌──────────────────────┐
│   Elder (User)   │◄────────►│  WhatsApp Business API │
└─────────────────┘          └──────────┬───────────┘
                                          │ webhook (voice note in/out)
                                          ▼
                              ┌───────────────────────┐
                              │   Backend (Cloud Fn)   │
                              │  - Receives audio      │
                              │  - Calls STT API       │
                              │  - Calls LLM for       │
                              │    summarization       │
                              │  - Computes status     │
                              │  - Writes to Firestore │
                              └───────────┬───────────┘
                                          │
                                          ▼
                              ┌───────────────────────┐
                              │      Firestore DB      │
                              │  - Family Circles      │
                              │  - Daily Log Entries    │
                              │  - Tasks/Reminders      │
                              └───────────┬───────────┘
                                          │ realtime sync
                                          ▼
                              ┌───────────────────────┐
                              │   Flutter App (Child)  │
                              │  - Dashboard            │
                              │  - Task creation        │
                              │  - Notifications (FCM)  │
                              └───────────────────────┘
```

### Components
- **Flutter App**: Child-facing only. iOS + Android via single codebase.
- **Firebase Auth**: Phone number OTP login for children.
- **Firestore**: Realtime database for Family Circles, daily logs, tasks.
- **Firebase Cloud Functions**: Webhook handlers, scheduling (Cloud Scheduler) for daily check-in triggers, orchestration of STT + LLM calls.
- **Firebase Cloud Messaging (FCM)**: Push notifications for missed check-ins and red-flag alerts.
- **WhatsApp Business API** (e.g., via Twilio's WhatsApp API or Gupshup): Sends/receives messages and voice notes to/from the elder.
- **Speech-to-Text API**: Google Cloud Speech-to-Text (strong Indian language + dialect support) or equivalent.
- **LLM API**: Claude or GPT for transcript summarization and structured extraction (mood, medication status, flagged concerns).

---

## 8. Data Model (Firestore)

### `familyCircles/{circleId}`
```
{
  circleId: string,
  elderName: string,
  elderPhoneNumber: string,
  preferredLanguage: string,
  checkInTime: string, // "09:00"
  interactionChannel: "whatsapp" | "call",
  members: [ { userId, name, role: "primary" | "sibling" } ],
  createdAt: timestamp
}
```

### `familyCircles/{circleId}/dailyLogs/{date}`
```
{
  date: string, // "2026-08-22"
  status: "green" | "yellow" | "red" | "grey",
  transcript: string,
  summary: string, // AI-generated one-liner
  medicationTaken: boolean | null,
  flaggedConcerns: [string],
  respondedAt: timestamp | null,
  audioUrl: string // optional, stored in Cloud Storage
}
```

### `familyCircles/{circleId}/tasks/{taskId}`
```
{
  taskId: string,
  createdBy: userId,
  text: string, // "Ask if the electricity bill was paid"
  status: "pending" | "delivered" | "acknowledged",
  createdAt: timestamp,
  deliveredInCheckInDate: string | null
}
```

### `users/{userId}`
```
{
  userId: string,
  name: string,
  phoneNumber: string,
  circleIds: [string]
}
```

---

## 9. Non-Functional Requirements

- **Privacy & Consent**: The elder must be clearly informed (via the first onboarding message) that their check-ins are being recorded, transcribed, and shared with named family members. No silent/covert monitoring.
- **Data retention**: Raw audio should be deletable/purgeable after transcription if storage/privacy is a concern; transcripts and summaries are the durable record.
- **Language support**: STT and LLM prompts must support at minimum one major Indian language beyond English for the demo (recommend Hindi or Kannada depending on team's fluency for testing).
- **Reliability**: Missed check-in detection must be timezone-aware and resilient to late-arriving webhooks (avoid false "missed" alerts due to processing delay).
- **Accessibility (elder side)**: Zero in-app UI required. All interaction happens through WhatsApp's native voice note interface, which the elder already knows.
- **Accessibility (child side, Flutter app)**: Large tap targets, high contrast for the status colors (colorblind-safe palette — don't rely on red/green alone; use icons + labels too).
- **Ethical framing**: The product must never present itself as a medical or diagnostic tool. Every red-flag alert should be worded as "may need attention" / "consider calling," never as a clinical assessment.

---

## 10. Known Risks and Build Constraints (Important for Antigravity + Code Review)

1. **WhatsApp Business API approval takes time.** For a hackathon build, do not block the demo on live WhatsApp API approval. Build with an abstraction layer (`MessagingChannel` interface) so the actual channel can be swapped between:
   - Live WhatsApp Business API (if approved in time)
   - A simulated in-app "Elder View" screen within the same Flutter app (a second screen that mimics receiving a WhatsApp-style prompt and recording a voice note) — **use this for the hackathon demo**, and pitch the real WhatsApp integration as the intended production channel.
2. **STT accuracy for regional languages/accents** may be imperfect — the LLM summarization step should be tolerant of noisy transcripts and should not invent details not present in the transcript (explicitly instruct the LLM: "if unclear, mark as unclear, do not guess").
3. **Do not let the LLM make medical judgments.** The prompt to the LLM must explicitly restrict it to: sentiment classification, keyword/symptom flagging, and medication-mention extraction — not diagnosis or medical advice generation.
4. **False missed-check-in alerts** are worse than a slightly delayed real alert — build in a grace period and a single gentle nudge before escalating to the family.

---

## 11. Success Metrics (for pitch/demo narrative)

- Time from elder's voice note to family dashboard update (target: under 30 seconds for demo).
- Number of taps required for elder to complete a check-in (target: 1–2 taps, i.e., open voice note + record + send, all native to WhatsApp).
- Clarity of the "why not just call" narrative in the pitch (see distinct value: reliability, shared visibility, historical record, task delivery — not replacing emotional connection).

---

## 12. Suggested Build Order for Antigravity

1. Firebase project setup: Auth, Firestore schema, Cloud Functions skeleton.
2. Flutter app shell: login, Family Circle creation, add member flow.
3. Simulated "Elder View" screen (in-app voice recording, mimics the WhatsApp prompt) — unblocks demo without waiting on WhatsApp API approval.
4. Cloud Function: receive audio → call STT → call LLM with structured extraction prompt → write to Firestore.
5. Dashboard feed UI: daily cards with status colors, expandable detail view.
6. Missed check-in scheduler (Cloud Scheduler + Cloud Function) + FCM push notification wiring.
7. Task/reminder creation UI + delivery into next check-in prompt text.
8. Polish pass: empty states, error states (no response yet, failed transcription), accessibility contrast check.
9. (If time remains) Real WhatsApp Business API integration to replace the simulated Elder View.

---

## 13. Open Questions for the Team to Resolve Before/During Build

- Which Indian language(s) will be supported in the demo, and does the team have a way to test STT accuracy for it?
- Who will play "the elder" during the live demo — will you use the simulated in-app view or attempt live WhatsApp integration?
- What LLM/STT API keys and quotas are available for the hackathon (rate limits matter if judges test it live)?
- Should the MVP support more than one elder per child (e.g., both parents), or is one elder per Family Circle sufficient for v1?

---

*End of PRD. This document is intended to be handed directly to an AI coding agent (Antigravity) for scaffolding, with GPT/Codex used as a secondary reviewer to check generated code against the architecture, data model, and non-functional requirements defined above.*