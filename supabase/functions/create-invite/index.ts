// ==================================================
// CREATE-INVITE — Supabase Edge Function
//
// Creates a time-limited invite for a family circle.
// Only the "primary" member of a circle may create invites.
// ==================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

interface CreateInvitePayload {
  circle_id: string;
  role: string;
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
    let body: CreateInvitePayload;
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

    if (!body.role || typeof body.role !== 'string' || body.role.trim() === '') {
      return new Response(
        JSON.stringify({ success: false, error: 'role is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 3. Verify caller is primary member of circle ──
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

    if (membership.role !== 'primary') {
      return new Response(
        JSON.stringify({ success: false, error: 'Only the primary member can create invites' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 4. Create invite with 24h expiration ──
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

    const { data: invite, error: insertError } = await adminClient
      .from('invites')
      .insert({
        circle_id: body.circle_id,
        created_by: user.id,
        role: body.role.trim(),
        status: 'active',
        expires_at: expiresAt,
      })
      .select('id')
      .single();

    if (insertError || !invite) {
      console.error('Invite insert failed:', insertError);
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to create invite' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 5. Success ──
    return new Response(
      JSON.stringify({ success: true, invite_id: invite.id }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Unhandled error in create-invite:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
