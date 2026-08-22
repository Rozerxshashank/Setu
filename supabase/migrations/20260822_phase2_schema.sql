-- ==================================================
-- PHASE 2: SUPABASE POSTGRESQL SCHEMA
-- ==================================================

-- 1. profiles
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    phone_number TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. family_circles
CREATE TABLE public.family_circles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elder_name TEXT NOT NULL,
    elder_phone_number TEXT,
    preferred_language TEXT,
    check_in_time TIME,
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    interaction_channel TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    consent_granted BOOLEAN NOT NULL DEFAULT false
);

-- 3. circle_members
CREATE TABLE public.circle_members (
    circle_id UUID NOT NULL REFERENCES public.family_circles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    name TEXT,
    PRIMARY KEY (circle_id, user_id)
);

-- 4. daily_logs
CREATE TABLE public.daily_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES public.family_circles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('green', 'yellow', 'red', 'grey')),
    transcript TEXT NOT NULL DEFAULT '',
    summary TEXT NOT NULL DEFAULT '',
    medication_taken BOOLEAN,
    flagged_concerns TEXT[] NOT NULL DEFAULT '{}',
    responded_at TIMESTAMPTZ,
    audio_url TEXT,
    provenance JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_daily_logs_circle_id ON public.daily_logs (circle_id);
CREATE INDEX idx_daily_logs_date ON public.daily_logs (date);
CREATE INDEX idx_daily_logs_circle_date ON public.daily_logs (circle_id, date);

-- 5. tasks
CREATE TABLE public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES public.family_circles(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.profiles(id),
    text TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'acknowledged')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivered_in_checkin_date DATE
);

CREATE INDEX idx_tasks_circle_id ON public.tasks (circle_id);
CREATE INDEX idx_tasks_circle_status ON public.tasks (circle_id, status);

-- 6. check_in_states
CREATE TABLE public.check_in_states (
    circle_id UUID NOT NULL REFERENCES public.family_circles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'responded', 'missed')),
    nudge_sent_at TIMESTAMPTZ,
    grey_log_created BOOLEAN NOT NULL DEFAULT false,
    final_alert_sent_at TIMESTAMPTZ,
    final_alert_claimed_at TIMESTAMPTZ,
    PRIMARY KEY (circle_id, date)
);

-- 7. invites
CREATE TABLE public.invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES public.family_circles(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.profiles(id),
    role TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'redeemed', 'revoked')),
    redeemed_by UUID REFERENCES public.profiles(id),
    redeemed_at TIMESTAMPTZ
);

CREATE INDEX idx_invites_circle_status ON public.invites (circle_id, status);

-- 8. fcm_tokens
CREATE TABLE public.fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, token)
);
