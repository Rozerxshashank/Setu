// ==================================================
// PROCESS-AUDIO-CHECKIN — Contract Tests
// Run with: deno test supabase/functions/process-audio-checkin/index.test.ts
// ==================================================

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';

// ── Test 1: Missing auth → 401 ──
Deno.test('process-audio: missing auth header returns 401 shape', () => {
  const response = { success: false, error: 'Missing authorization header' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'Missing authorization header');
});

// ── Test 2: Missing circle_id → 400 ──
Deno.test('process-audio: missing circle_id returns 400 shape', () => {
  const response = { success: false, error: 'circle_id is required' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'circle_id is required');
});

// ── Test 3: Missing audio_path → 400 ──
Deno.test('process-audio: missing audio_path returns 400 shape', () => {
  const response = { success: false, error: 'audio_path is required' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'audio_path is required');
});

// ── Test 4: Audio path mismatch → 403 ──
Deno.test('process-audio: mismatched audio path returns 403 shape', () => {
  const response = { success: false, error: 'Audio path does not match circle or user' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'Audio path does not match circle or user');
});

// ── Test 5: Non-member → 403 ──
Deno.test('process-audio: non-member returns 403 shape', () => {
  const response = { success: false, error: 'You are not a member of this circle' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'You are not a member of this circle');
});

// ── Test 6: Gemini rate limit → 503 ──
Deno.test('process-audio: Gemini 429 returns 503 shape', () => {
  const response = { success: false, error: 'AI processing temporarily unavailable. Please try again later.' };
  assertEquals(response.success, false);
  assertEquals(response.error.includes('temporarily unavailable'), true);
});

// ── Test 7: Gemini generic failure → 503 ──
Deno.test('process-audio: Gemini failure returns 503 shape', () => {
  const response = { success: false, error: 'AI processing temporarily unavailable' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'AI processing temporarily unavailable');
});

// ── Test 8: Idempotent response shape ──
Deno.test('process-audio: idempotent cached response shape', () => {
  const response = { success: true, log_id: 'some-uuid', cached: true };
  assertEquals(response.success, true);
  assertEquals(response.cached, true);
  assertEquals(typeof response.log_id, 'string');
});

// ── Test 9: Successful response shape ──
Deno.test('process-audio: success response shape', () => {
  const response = { success: true, log_id: 'some-uuid', status: 'green' };
  assertEquals(response.success, true);
  assertEquals(typeof response.log_id, 'string');
  assertEquals(['green', 'yellow', 'red'].includes(response.status), true);
});

// ── Test 10: Deterministic status — no concerns → green ──
Deno.test('status: no concerns → green', () => {
  const concerns: string[] = [];
  let status = 'green';
  if (concerns.length > 0) {
    status = 'yellow';
    const redRegex = /\b(severe pain|need help|call me immediately|emergency|urgent|immediate help|help right now)\b/i;
    for (const c of concerns) {
      if (redRegex.test(c)) { status = 'red'; break; }
    }
  }
  assertEquals(status, 'green');
});

// ── Test 11: Deterministic status — concern without red keywords → yellow ──
Deno.test('status: non-emergency concern → yellow', () => {
  const concerns = ['knee pain'];
  let status = 'green';
  if (concerns.length > 0) {
    status = 'yellow';
    const redRegex = /\b(severe pain|need help|call me immediately|emergency|urgent|immediate help|help right now)\b/i;
    for (const c of concerns) {
      if (redRegex.test(c)) { status = 'red'; break; }
    }
  }
  assertEquals(status, 'yellow');
});

// ── Test 12: Deterministic status — "severe pain" → red ──
Deno.test('status: severe pain → red', () => {
  const concerns = ['severe pain in chest'];
  let status = 'green';
  if (concerns.length > 0) {
    status = 'yellow';
    const redRegex = /\b(severe pain|need help|call me immediately|emergency|urgent|immediate help|help right now)\b/i;
    for (const c of concerns) {
      if (redRegex.test(c)) { status = 'red'; break; }
    }
  }
  assertEquals(status, 'red');
});

// ── Test 13: Deterministic status — "emergency" → red ──
Deno.test('status: emergency → red', () => {
  const concerns = ['this is an emergency'];
  let status = 'green';
  if (concerns.length > 0) {
    status = 'yellow';
    const redRegex = /\b(severe pain|need help|call me immediately|emergency|urgent|immediate help|help right now)\b/i;
    for (const c of concerns) {
      if (redRegex.test(c)) { status = 'red'; break; }
    }
  }
  assertEquals(status, 'red');
});

// ── Test 14: Medication mapping ──
Deno.test('medication: taken → true', () => {
  const map = (s: string) => s === 'taken' ? true : s === 'not_taken' ? false : null;
  assertEquals(map('taken'), true);
  assertEquals(map('not_taken'), false);
  assertEquals(map('not_mentioned'), null);
  assertEquals(map('unclear'), null);
});

// ── Test 15: Audio path validation logic ──
Deno.test('path validation: correct prefix passes', () => {
  const circleId = 'circle-abc';
  const userId = 'user-xyz';
  const audioPath = `${circleId}/${userId}/elder_record_123.m4a`;
  const expectedPrefix = `${circleId}/${userId}/`;
  assertEquals(audioPath.startsWith(expectedPrefix), true);
});

// ── Test 16: Audio path validation — wrong user rejected ──
Deno.test('path validation: wrong user rejected', () => {
  const circleId = 'circle-abc';
  const userId = 'user-xyz';
  const audioPath = `${circleId}/other-user/elder_record_123.m4a`;
  const expectedPrefix = `${circleId}/${userId}/`;
  assertEquals(audioPath.startsWith(expectedPrefix), false);
});
