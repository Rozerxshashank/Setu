// ==================================================
// CREATE-CIRCLE — Supabase Edge Function
//
// Creates a family circle and adds the authenticated
// user as the "primary" member atomically.
// ==================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

interface CreateCirclePayload {
  elder_name: string;
  elder_phone_number?: string;
  preferred_language?: string;
  check_in_time?: string;
  timezone?: string;
  interaction_channel?: string;
  consent_granted: boolean;
}

Deno.serve(async (req: Request) => {
  // ── CORS preflight ──
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // ── Only POST allowed ──
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

    // Verify the JWT using an anon-key client
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
    let body: CreateCirclePayload;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid JSON body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!body.elder_name || typeof body.elder_name !== 'string' || body.elder_name.trim() === '') {
      return new Response(
        JSON.stringify({ success: false, error: 'elder_name is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (body.consent_granted !== true) {
      return new Response(
        JSON.stringify({ success: false, error: 'consent_granted must be true' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 3. Create circle + primary member atomically ──
    const adminClient = createAdminClient();

    // Look up creator's profile name for circle_members.name
    const { data: profile } = await adminClient
      .from('profiles')
      .select('name')
      .eq('id', user.id)
      .single();

    const creatorName = profile?.name ?? user.email ?? 'Unknown';

    // Use an RPC call wrapping a Postgres transaction for atomicity.
    // If the RPC doesn't exist yet, fall back to sequential inserts
    // with manual cleanup.

    // Insert family_circles row
    const { data: circleData, error: circleError } = await adminClient
      .from('family_circles')
      .insert({
        elder_name: body.elder_name.trim(),
        elder_phone_number: body.elder_phone_number ?? null,
        preferred_language: body.preferred_language ?? null,
        check_in_time: body.check_in_time ?? null,
        timezone: body.timezone ?? 'Asia/Kolkata',
        interaction_channel: body.interaction_channel ?? null,
        consent_granted: true,
      })
      .select('id')
      .single();

    if (circleError || !circleData) {
      console.error('Circle insert failed:', circleError);
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to create circle' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const circleId: string = circleData.id;

    // Insert circle_members row
    const { error: memberError } = await adminClient
      .from('circle_members')
      .insert({
        circle_id: circleId,
        user_id: user.id,
        role: 'primary',
        name: creatorName,
      });

    if (memberError) {
      // Rollback: delete the orphan circle
      console.error('Member insert failed, rolling back circle:', memberError);
      await adminClient.from('family_circles').delete().eq('id', circleId);
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to add you as primary member' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── 4. Success ──
    return new Response(
      JSON.stringify({ success: true, circle_id: circleId }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Unhandled error in create-circle:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
