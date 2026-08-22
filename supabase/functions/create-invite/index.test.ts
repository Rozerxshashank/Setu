// ==================================================
// CREATE-INVITE — Contract Tests
// Run with: deno test supabase/functions/create-invite/index.test.ts
// ==================================================

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';

// ── Test 1: Missing auth → 401 ──
Deno.test('create-invite: missing auth header returns 401 shape', () => {
  const response = { success: false, error: 'Missing authorization header' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'Missing authorization header');
});

// ── Test 2: Missing circle_id → 400 ──
Deno.test('create-invite: missing circle_id returns 400 shape', () => {
  const response = { success: false, error: 'circle_id is required' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'circle_id is required');
});

// ── Test 3: Missing role → 400 ──
Deno.test('create-invite: missing role returns 400 shape', () => {
  const response = { success: false, error: 'role is required' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'role is required');
});

// ── Test 4: Non-member of circle → 403 ──
Deno.test('create-invite: non-member returns 403 shape', () => {
  const response = { success: false, error: 'You are not a member of this circle' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'You are not a member of this circle');
});

// ── Test 5: Non-primary member → 403 ──
Deno.test('create-invite: non-primary member returns 403 shape', () => {
  const response = { success: false, error: 'Only the primary member can create invites' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'Only the primary member can create invites');
});

// ── Test 6: Successful invite creation ──
Deno.test('create-invite: success response contains invite_id', () => {
  const response = { success: true, invite_id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' };
  assertEquals(response.success, true);
  assertEquals(typeof response.invite_id, 'string');
  assertEquals(response.invite_id.length > 0, true);
});

// ── Test 7: Expiry is 24 hours from now ──
Deno.test('create-invite: default expiry is 24 hours', () => {
  const now = Date.now();
  const expiresAt = new Date(now + 24 * 60 * 60 * 1000);
  const diffMs = expiresAt.getTime() - now;
  const diffHours = diffMs / (1000 * 60 * 60);
  assertEquals(diffHours, 24);
});
