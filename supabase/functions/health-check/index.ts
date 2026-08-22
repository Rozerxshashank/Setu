// ==================================================
// HEALTH CHECK — Supabase Edge Function
// Verifies Edge Functions runtime is operational.
// ==================================================

import { corsHeaders } from '../_shared/cors.ts';

Deno.serve((req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const body = JSON.stringify({
    status: 'ok',
    service: 'supabase-edge-functions',
    timestamp: new Date().toISOString(),
  });

  return new Response(body, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
});
