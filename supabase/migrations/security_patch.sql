-- ==================================================
-- PHASE 10: SECURITY VERIFICATION PATCH
-- ==================================================
-- Revoke execution of create_daily_log_with_tasks from
-- PUBLIC, anon, and authenticated roles to prevent direct
-- client execution via PostgREST RPC.
-- Grant execution ONLY to service_role (used by Edge Functions).

REVOKE EXECUTE ON FUNCTION public.create_daily_log_with_tasks(
  UUID, DATE, TEXT, TEXT, TEXT, BOOLEAN, TEXT[], TIMESTAMPTZ, TEXT, JSONB, TEXT, JSONB
) FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.create_daily_log_with_tasks(
  UUID, DATE, TEXT, TEXT, TEXT, BOOLEAN, TEXT[], TIMESTAMPTZ, TEXT, JSONB, TEXT, JSONB
) FROM anon;

REVOKE EXECUTE ON FUNCTION public.create_daily_log_with_tasks(
  UUID, DATE, TEXT, TEXT, TEXT, BOOLEAN, TEXT[], TIMESTAMPTZ, TEXT, JSONB, TEXT, JSONB
) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.create_daily_log_with_tasks(
  UUID, DATE, TEXT, TEXT, TEXT, BOOLEAN, TEXT[], TIMESTAMPTZ, TEXT, JSONB, TEXT, JSONB
) TO service_role;
