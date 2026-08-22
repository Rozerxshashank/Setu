# Supabase Edge Functions — Setu

## Overview

These Edge Functions will replace Firebase Cloud Functions as part of the
₹0 Supabase migration. They run on Deno Deploy via the Supabase free tier.

## Current Functions

| Function                | Method | Status        | Auth     | DB Tables                         | Dependencies                 | Description                       |
|-------------------------|--------|---------------|----------|-----------------------------------|------------------------------|-----------------------------------|
| `health-check`          | GET    | Scaffolded    | None     | —                                 | —                            | Runtime health verification       |
| `create-circle`         | POST   | Implemented   | Required | `family_circles`, `circle_members`| —                            | Family circle creation            |
| `create-invite`         | POST   | Implemented   | Required | `invites`, `circle_members`       | —                            | Invite creation (primary only)    |
| `join-circle`           | POST   | Implemented   | Required | `circle_members`, `invites`       | —                            | Invite redemption                 |
| `process-audio-checkin` | POST   | Implemented   | Required | `daily_logs`, `tasks`             | Supabase Storage, Gemini API | Audio → Gemini → DailyLog pipeline|
| `daily-scheduler`       | POST   | Not started   | Service  | `check_in_states`, `daily_logs`   | pg_cron                      | pg_cron triggered daily pipeline  |

## Project Structure

```
supabase/functions/
├── _shared/
│   ├── cors.ts              # Reusable CORS headers
│   └── supabase-admin.ts    # Service-role admin client factory
├── create-circle/
│   ├── index.ts             # Family circle creation
│   └── index.test.ts        # Contract tests
├── create-invite/
│   ├── index.ts             # Invite creation (primary only)
│   └── index.test.ts        # Contract tests
├── health-check/
│   └── index.ts             # Health check endpoint
├── join-circle/
│   ├── index.ts             # Invite redemption
│   └── index.test.ts        # Contract tests
├── process-audio-checkin/
│   ├── index.ts             # Audio → Gemini → daily_logs + tasks
│   └── index.test.ts        # Contract tests
└── README.md                # This file
```

## Required Secrets

These secrets must be configured in the Supabase Dashboard under
**Project Settings → Edge Functions → Secrets** before deploying
functions that depend on them.

| Secret                      | Used By           | Phase |
|-----------------------------|-------------------|-------|
| `SUPABASE_URL`              | All functions     | 6     |
| `SUPABASE_SERVICE_ROLE_KEY` | All functions     | 6     |
| `GEMINI_API_KEY`            | `process-audio`   | 8+    |
| `FCM_SERVICE_ACCOUNT_JSON`  | `daily-scheduler` | 10+   |

> **IMPORTANT**: Never commit secret values to source control.
> Secrets are injected at runtime by the Supabase platform.

## Local Development

### Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli) installed
- Docker running (required by `supabase start`)

### Run locally

```bash
# Start local Supabase (if not already running)
supabase start

# Serve all Edge Functions locally
supabase functions serve

# Serve a single function
supabase functions serve health-check
```

### Test the health-check endpoint locally

```bash
curl -i http://localhost:54321/functions/v1/health-check
```

Expected response:

```json
{
  "status": "ok",
  "service": "supabase-edge-functions",
  "timestamp": "2026-08-22T17:30:00.000Z"
}
```

### Test create-circle locally

```bash
# Should fail with 401 (no auth header)
curl -i -X POST http://localhost:54321/functions/v1/create-circle \
  -H 'Content-Type: application/json' \
  -d '{"elder_name": "Test", "consent_granted": true}'

# With a valid JWT:
curl -i -X POST http://localhost:54321/functions/v1/create-circle \
  -H 'Authorization: Bearer <USER_JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"elder_name": "Amma", "consent_granted": true}'
```

Expected success response:

```json
{
  "success": true,
  "circle_id": "<uuid>"
}
```

### Test create-invite locally

```bash
# Without auth (should return 401)
curl -i -X POST http://localhost:54321/functions/v1/create-invite \
  -H 'Content-Type: application/json' \
  -d '{"circle_id": "<uuid>", "role": "member"}'

# With auth (must be primary member)
curl -i -X POST http://localhost:54321/functions/v1/create-invite \
  -H 'Authorization: Bearer <USER_JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"circle_id": "<uuid>", "role": "member"}'
```

Expected success response:

```json
{
  "success": true,
  "invite_id": "<uuid>"
}
```

### Test join-circle locally

```bash
curl -i -X POST http://localhost:54321/functions/v1/join-circle \
  -H 'Authorization: Bearer <USER_JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"invite_id": "<uuid>"}'
```

Expected success response:

```json
{
  "success": true,
  "circle_id": "<uuid>"
}
```

## Daily Log Atomic Layer (Phase 10)

- **RPC Name**: `create_daily_log_with_tasks`
- **Idempotency Strategy**: Uses `processing_key = audio_path` with a unique index on `public.daily_logs(processing_key)`. If a duplicate `processing_key` is submitted, the RPC immediately returns `{ "success": true, "duplicate": true, "daily_log_id": "<existing-id>" }` without creating duplicate records.
- **Task State Machine**:
  - Allowed transitions: `pending` → `delivered`, `pending` → `acknowledged`
  - Enforced via SQL guard (`WHERE status = 'pending'`). Non-pending tasks cannot be downgraded or mutated.
- **Atomicity**: Writes `daily_logs` and updates affected `tasks` in a single PostgreSQL transaction inside a `SECURITY DEFINER` function.

## Deployment

> Do NOT deploy until the relevant migration phase is approved.

```bash
# Deploy a single function
supabase functions deploy health-check --no-verify-jwt

# Deploy all functions
supabase functions deploy --no-verify-jwt
```

The `--no-verify-jwt` flag is used during early development.
Production functions that require authentication should omit this flag
so Supabase enforces JWT verification automatically.

## Testing against the remote project

```bash
curl -i https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/health-check
```

## Notes

- Edge Functions run on Deno, not Node.js.
- Use `Deno.serve()` (not `serve()` from `std/http`).
- Import from `https://esm.sh/` for npm packages.
- The `_shared/` directory is not deployed as a function; it is only
  used for shared imports.

