# Setu Production Manual Setup Guide

This guide covers the necessary steps to deploy the Setu production architecture. The backend has been completely migrated to Supabase.

## 1. Supabase Project Setup
1. Go to the [Supabase Dashboard](https://supabase.com/dashboard) and create a new project `Setu-Prod`.
2. Wait for the database and API endpoints to provision.
3. In **Authentication > Providers**, enable **Email** and configure any OAuth providers you need.
4. (Optional) Enable **Anonymous Sign-ins** if you want to support Demo Mode without a login.

## 2. Environment Variables (`.env`)
Create a `.env` file in the root directory (this file is ignored by git) with your Supabase keys:

```
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_anon_key
```

## 3. Database Schema and Storage
1. Navigate to the **SQL Editor** in Supabase and run your schema migrations to create the `profiles`, `family_circles`, `daily_logs`, and `tasks` tables.
2. Navigate to **Storage** and create a new public bucket named `audio_inbox` for storing elder voice check-ins.
3. Apply Row Level Security (RLS) policies to ensure users can only access their own family circle data.

## 4. Supabase Edge Functions (Deno/TypeScript)
We use Supabase Edge Functions to handle the background processing (e.g. `daily-scheduler`, audio processing).

1. Install the Supabase CLI: `brew install supabase/tap/supabase` (Mac) or `npm install -g supabase`.
2. Login: `supabase login`
3. Link your project: `supabase link --project-ref your-project-ref`
4. Deploy the functions:
   ```bash
   supabase functions deploy daily-scheduler --no-verify-jwt
   supabase functions deploy process-audio --no-verify-jwt
   ```

## 5. Secret Management for Edge Functions
1. In the Supabase Dashboard, go to **Edge Functions > Secrets**.
2. Add the following secrets:
   - `GEMINI_API_KEY`: Generate this from Google AI Studio.
   - `WHATSAPP_WEBHOOK_SECRET`: A cryptographic string provided by Twilio/Gupshup for webhook validation (Phase 4).

## 6. WhatsApp Integration (Phase 4)
1. Complete Meta's WhatsApp Business API verification.
2. Configure your provider (Twilio/Gupshup) to point the webhook URL to your deployed `whatsapp-webhook` Supabase Edge Function.

## 7. Rollback & Incident Runbook
- **If LLM begins hallucinating:** Update the model version in your Edge Functions code (e.g., to `gemini-1.5-flash-001`) and redeploy functions.
- **If malicious traffic hits the webhook:** Rotate `WHATSAPP_WEBHOOK_SECRET` in the Supabase Dashboard immediately and redeploy functions.
