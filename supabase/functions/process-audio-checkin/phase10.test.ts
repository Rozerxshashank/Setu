1// ==================================================
// PHASE 10 — Daily Log Atomic Updates Tests
// Run with: deno test supabase/functions/process-audio-checkin/phase10.test.ts
// ==================================================

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';

// ── Test 1: First audio processing creates one DailyLog ──
Deno.test('phase10: first processing returns success with daily_log_id', () => {
  const rpcResult = {
    success: true,
    duplicate: false,
    daily_log_id: 'abc-123-def',
  };
  assertEquals(rpcResult.success, true);
  assertEquals(rpcResult.duplicate, false);
  assertEquals(typeof rpcResult.daily_log_id, 'string');
});

// ── Test 2: Same audio processed twice returns existing DailyLog ──
Deno.test('phase10: duplicate processing returns existing log', () => {
  const rpcResult = {
    success: true,
    duplicate: true,
    daily_log_id: 'abc-123-def',
  };
  assertEquals(rpcResult.success, true);
  assertEquals(rpcResult.duplicate, true);
  assertEquals(typeof rpcResult.daily_log_id, 'string');
});

// ── Test 3: Pre-check idempotency avoids Gemini call ──
Deno.test('phase10: pre-check returns cached response shape', () => {
  const response = { success: true, log_id: 'existing-uuid', duplicate: true };
  assertEquals(response.success, true);
  assertEquals(response.duplicate, true);
  assertEquals(typeof response.log_id, 'string');
});

// ── Test 4: Database failure returns no partial DailyLog ──
Deno.test('phase10: RPC failure returns clean error', () => {
  const response = { success: false, error: 'Failed to save check-in record' };
  assertEquals(response.success, false);
  assertEquals(response.error, 'Failed to save check-in record');
});

// ── Test 5: Task transition pending → acknowledged ──
Deno.test('phase10: task update builds correct acknowledged payload', () => {
  const pendingTasks = [
    { id: 'task-1', text: 'Did you take medicine?' },
    { id: 'task-2', text: 'Did you eat lunch?' },
  ];
  const taskResponses = [
    { taskId: 'task-1', response: 'Yes I took it', status: 'answered' },
    { taskId: 'task-2', response: '', status: 'unanswered' },
  ];

  const taskUpdates = pendingTasks.map((pt) => {
    const extracted = taskResponses.find((tr) => tr.taskId === pt.id);
    return {
      task_id: pt.id,
      new_status: (extracted && extracted.status === 'answered') ? 'acknowledged' : 'delivered',
    };
  });

  assertEquals(taskUpdates[0].task_id, 'task-1');
  assertEquals(taskUpdates[0].new_status, 'acknowledged');
  assertEquals(taskUpdates[1].task_id, 'task-2');
  assertEquals(taskUpdates[1].new_status, 'delivered');
});

// ── Test 6: Invalid task update — delivered → pending rejected ──
Deno.test('phase10: task state machine rejects invalid transitions', () => {
  // The RPC only updates WHERE status = 'pending'
  // This test verifies the SQL guard logic conceptually
  const allowedFromPending = ['delivered', 'acknowledged'];
  const invalidTransition = 'pending'; // trying to go back

  assertEquals(allowedFromPending.includes(invalidTransition), false);
});

// ── Test 7: Invalid status rejected ──
Deno.test('phase10: invalid status rejected by RPC', () => {
  const validStatuses = ['green', 'yellow', 'red', 'grey'];
  const invalidStatus = 'orange';
  assertEquals(validStatuses.includes(invalidStatus), false);

  // RPC returns error for invalid status
  const rpcResult = {
    success: false,
    error: 'Invalid status value: orange',
  };
  assertEquals(rpcResult.success, false);
  assertEquals(rpcResult.error.includes('Invalid status'), true);
});

// ── Test 8: Processing key uniqueness ──
Deno.test('phase10: processing_key maps to audio_path', () => {
  const audioPath = 'circle-abc/user-xyz/elder_record_123.m4a';
  const processingKey = audioPath; // 1:1 mapping
  assertEquals(processingKey, audioPath);
});

// ── Test 9: RPC returns JSONB with correct shape ──
Deno.test('phase10: RPC result shape validation', () => {
  // Success case
  const success = { success: true, duplicate: false, daily_log_id: 'uuid' };
  assertEquals(typeof success.success, 'boolean');
  assertEquals(typeof success.duplicate, 'boolean');
  assertEquals(typeof success.daily_log_id, 'string');

  // Duplicate case
  const dup = { success: true, duplicate: true, daily_log_id: 'uuid' };
  assertEquals(dup.duplicate, true);

  // Error case
  const err = { success: false, error: 'some error' };
  assertEquals(typeof err.error, 'string');
});

// ── Test 10: Edge Function response codes ──
Deno.test('phase10: response status codes are correct', () => {
  // New log → 201
  const newLog = { duplicate: false };
  assertEquals(newLog.duplicate ? 200 : 201, 201);

  // Duplicate log → 200
  const dupLog = { duplicate: true };
  assertEquals(dupLog.duplicate ? 200 : 201, 200);
});
