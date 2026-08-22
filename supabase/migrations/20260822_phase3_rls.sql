-- ==================================================
-- PHASE 3: SUPABASE ROW LEVEL SECURITY (RLS)
-- ==================================================

-- 1. Enable RLS on all public tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_circles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_in_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 2. Create SECURITY DEFINER helper function for circle membership
CREATE OR REPLACE FUNCTION public.is_circle_member(circle_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.circle_members 
    WHERE circle_members.circle_id = $1 
      AND circle_members.user_id = auth.uid()
  );
$$;

-- 3. Profiles Policies
CREATE POLICY "Users can view own profile" 
ON public.profiles FOR SELECT TO authenticated 
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
ON public.profiles FOR UPDATE TO authenticated 
USING (auth.uid() = id);

-- 4. Family Circles Policies
CREATE POLICY "Members can view circles" 
ON public.family_circles FOR SELECT TO authenticated 
USING (public.is_circle_member(id));

-- 5. Circle Members Policies
CREATE POLICY "Members can view circle members" 
ON public.circle_members FOR SELECT TO authenticated 
USING (public.is_circle_member(circle_id));

-- 6. Daily Logs Policies
CREATE POLICY "Members can view daily logs" 
ON public.daily_logs FOR SELECT TO authenticated 
USING (public.is_circle_member(circle_id));

-- 7. Tasks Policies
CREATE POLICY "Members can view tasks" 
ON public.tasks FOR SELECT TO authenticated 
USING (public.is_circle_member(circle_id));

CREATE POLICY "Members can insert pending tasks" 
ON public.tasks FOR INSERT TO authenticated 
WITH CHECK (
    public.is_circle_member(circle_id) AND 
    created_by = auth.uid() AND 
    status = 'pending'
);

-- 8. Check-In States Policies
CREATE POLICY "Members can view check_in_states" 
ON public.check_in_states FOR SELECT TO authenticated 
USING (public.is_circle_member(circle_id));

-- 9. Invites Policies
-- Client SELECT/INSERT/UPDATE/DELETE blocked. Edge functions will manage.
-- (No policies created, which defaults to deny all for public access)

-- 10. FCM Tokens Policies
CREATE POLICY "Users can view own tokens" 
ON public.fcm_tokens FOR SELECT TO authenticated 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tokens" 
ON public.fcm_tokens FOR INSERT TO authenticated 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own tokens" 
ON public.fcm_tokens FOR DELETE TO authenticated 
USING (auth.uid() = user_id);
