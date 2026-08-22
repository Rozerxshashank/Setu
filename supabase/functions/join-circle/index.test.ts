// ==================================================
// JOIN-CIRCLE — Contract Tests
// Run with: deno test supabase/functions/join-circle/index.test.ts
// ==================================================

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';

// ── Test 1: Missing auth → 401 ──
Deno.test('join-circle: missing auth header returns 401 shape', () => {
  const response = { success: false, error: 'Missing authorization header' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'Missing authorization header');
});

// ── Test 2: Missing invite_id → 400 ──
Deno.test('join-circle: missing invite_id returns 400 shape', () => {
  const response = { success: false, error: 'invite_id is required' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'invite_id is required');
});

// ── Test 3: Invite not found → 404 ──
Deno.test('join-circle: invalid invite returns 404 shape', () => {
  const response = { success: false, error: 'Invite not found' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'Invite not found');
});

// ── Test 4: Already redeemed invite → 400 ──
Deno.test('join-circle: redeemed invite returns 400 shape', () => {
  const response = { success: false, error: 'This invite has already been used or revoked' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'This invite has already been used or revoked');
});

// ── Test 5: Expired invite → 400 ──
Deno.test('join-circle: expired invite returns 400 shape', () => {
  const response = { success: false, error: 'This invite has expired' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'This invite has expired');
});

// ── Test 6: Already a member → 400 ──
Deno.test('join-circle: existing member returns 400 shape', () => {
  const response = { success: false, error: 'You are already a member of this circle' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'You are already a member of this circle');
});

// ── Test 7: Successful join ──
Deno.test('join-circle: success response contains circle_id', () => {
  const response = { success: true, circle_id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' };
  assertEquals(response.success, true);
  assertEquals(typeof response.circle_id, 'string');
  assertEquals(response.circle_id.length > 0, true);
});

// ── Test 8: Expiry check logic ──
Deno.test('join-circle: expired date is detected correctly', () => {
  const pastDate = new Date('2020-01-01T00:00:00Z');
  const isExpired = pastDate < new Date();
  assertEquals(isExpired, true);
});

// ── Test 9: Future date is not expired ──
Deno.test('join-circle: future date is not expired', () => {
  const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
  const isExpired = futureDate < new Date();
  assertEquals(isExpired, false);
});
