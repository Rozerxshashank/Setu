-- ==================================================
-- PHASE 10: DAILY LOG ATOMIC WRITES
-- ==================================================

-- 1. Add processing_key for idempotency
ALTER TABLE public.daily_logs
ADD COLUMN IF NOT EXISTS processing_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_logs_processing_key
ON public.daily_logs (processing_key)
WHERE processing_key IS NOT NULL;

-- 2. Atomic RPC: create_daily_log_with_tasks
--
-- Inserts a daily_log and updates pending tasks in a single
-- transaction. Returns the existing log if processing_key
-- already exists (idempotency).
--
-- SECURITY DEFINER: runs with owner privileges so RLS is
-- bypassed. Only Edge Functions (service role) should call this.

CREATE OR REPLACE FUNCTION public.create_daily_log_with_tasks(
  p_circle_id UUID,
  p_date DATE,
  p_status TEXT,
  p_transcript TEXT,
  p_summary TEXT,
  p_medication_taken BOOLEAN,
  p_flagged_concerns TEXT[],
  p_responded_at TIMESTAMPTZ,
  p_audio_url TEXT,
  p_provenance JSONB,
  p_processing_key TEXT,
  p_task_updates JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id UUID;
  v_existing_id UUID;
  v_task JSONB;
  v_task_id UUID;
  v_new_status TEXT;
BEGIN
  -- ── Validate status ──
  IF p_status NOT IN ('green', 'yellow', 'red', 'grey') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid status value: ' || p_status
    );
  END IF;

  -- ── Idempotency: check processing_key ──
  IF p_processing_key IS NOT NULL THEN
    SELECT id INTO v_existing_id
    FROM public.daily_logs
    WHERE processing_key = p_processing_key
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'duplicate', true,
        'daily_log_id', v_existing_id
      );
    END IF;
  END IF;

  -- ── Insert daily_log ──
  INSERT INTO public.daily_logs (
    circle_id,
    date,
    status,
    transcript,
    summary,
    medication_taken,
    flagged_concerns,
    responded_at,
    audio_url,
    provenance,
    processing_key
  ) VALUES (
    p_circle_id,
    p_date,
    p_status,
    p_transcript,
    p_summary,
    p_medication_taken,
    p_flagged_concerns,
    p_responded_at,
    p_audio_url,
    p_provenance,
    p_processing_key
  )
  RETURNING id INTO v_log_id;

  -- ── Update pending tasks ──
  -- p_task_updates is a JSON array of:
  --   [{ "task_id": "uuid", "new_status": "delivered"|"acknowledged" }]
  FOR v_task IN SELECT * FROM jsonb_array_elements(p_task_updates)
  LOOP
    v_task_id := (v_task ->> 'task_id')::UUID;
    v_new_status := v_task ->> 'new_status';

    -- Validate allowed transitions (only from pending)
    IF v_new_status NOT IN ('delivered', 'acknowledged') THEN
      CONTINUE;
    END IF;

    UPDATE public.tasks
    SET
      status = v_new_status,
      delivered_in_checkin_date = p_date
    WHERE id = v_task_id
      AND status = 'pending';  -- Guard: only transition from pending
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'duplicate', false,
    'daily_log_id', v_log_id
  );
END;
$$;
