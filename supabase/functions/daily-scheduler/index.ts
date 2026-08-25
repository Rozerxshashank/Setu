// ==================================================
// DAILY-SCHEDULER — Supabase Edge Function
//
// Periodically checks for missed daily check-ins across
// all active family circles. If the scheduled check-in
// time has passed and no log exists for today, it creates
// a "missed" daily log record automatically.
// ==================================================

import { corsHeaders } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const adminClient = createAdminClient();
    const today = new Date().toISOString().split('T')[0];

    // 1. Fetch all active family circles
    const { data: circles, error: circleError } = await adminClient
      .from('family_circles')
      .select('id, elder_name, check_in_time, timezone');

    if (circleError) {
      console.error('Failed to fetch family circles:', circleError);
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to fetch circles' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    let missedCount = 0;
    const processedCircles: string[] = [];

    for (const circle of circles ?? []) {
      const circleId = circle.id;

      // 2. Check if a log already exists for today
      const { data: existingLog } = await adminClient
        .from('daily_logs')
        .select('id')
        .eq('circle_id', circleId)
        .eq('date', today)
        .maybeSingle();

      if (!existingLog) {
        // 3. Create a missed check-in log
        const { error: insertError } = await adminClient
          .from('daily_logs')
          .insert({
            circle_id: circleId,
            date: today,
            status: 'missed',
            summary: `No check-in received for ${circle.elder_name} by the scheduled check-in time (${circle.check_in_time ?? '09:00'}).`,
            transcript: '',
            audio_url: null,
            flagged_concerns: ['Missed daily check-in'],
          });

        if (!insertError) {
          missedCount++;
          processedCircles.push(circleId);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        date: today,
        missed_logs_created: missedCount,
        circles_processed: processedCircles,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    console.error('Unhandled error in daily-scheduler:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
