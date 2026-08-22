// ==================================================
// JOIN-CIRCLE — Supabase Edge Function
//
// Redeems an invite and adds the authenticated user
// to the circle as a member.
// ==================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

interface JoinCirclePayload {
  invite_id: string;
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
    let body: JoinCirclePayload;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid JSON body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!body.invite_id || typeof body.invite_id !== 'string') {
      return new Response(
        JSON.stringify({ success: false, error: 'invite_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 3. Look up invite ──
    const adminClient = createAdminClient();

    const { data: invite, error: inviteError } = await adminClient
      .from('invites')
      .select('*')
      .eq('id', body.invite_id)
      .single();

    if (inviteError || !invite) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invite not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 4. Validate invite state ──
    if (invite.status !== 'active') {
      return new Response(
        JSON.stringify({ success: false, error: 'This invite has already been used or revoked' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (new Date(invite.expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ success: false, error: 'This invite has expired' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 5. Check if user is already a member ──
    const { data: existingMember } = await adminClient
      .from('circle_members')
      .select('user_id')
      .eq('circle_id', invite.circle_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existingMember) {
      return new Response(
        JSON.stringify({ success: false, error: 'You are already a member of this circle' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 6. Redeem: mark invite + add member ──

    // Look up joiner's profile name
    const { data: profile } = await adminClient
      .from('profiles')
      .select('name')
      .eq('id', user.id)
      .single();

    const joinerName = profile?.name ?? user.email ?? 'Unknown';

    // 6a. Update invite to redeemed
    const { error: redeemError } = await adminClient
      .from('invites')
      .update({
        status: 'redeemed',
        redeemed_by: user.id,
        redeemed_at: new Date().toISOString(),
      })
      .eq('id', body.invite_id)
      .eq('status', 'active'); // guard against race condition

    if (redeemError) {
      console.error('Invite redeem failed:', redeemError);
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to redeem invite' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // 6b. Insert circle_members row
    const { error: memberError } = await adminClient
      .from('circle_members')
      .insert({
        circle_id: invite.circle_id,
        user_id: user.id,
        role: invite.role,
        name: joinerName,
      });

    if (memberError) {
      // Rollback: revert invite back to active
      console.error('Member insert failed, reverting invite:', memberError);
      await adminClient
        .from('invites')
        .update({ status: 'active', redeemed_by: null, redeemed_at: null })
        .eq('id', body.invite_id);

      return new Response(
        JSON.stringify({ success: false, error: 'Failed to join circle' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 7. Success ──
    return new Response(
      JSON.stringify({ success: true, circle_id: invite.circle_id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Unhandled error in join-circle:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
