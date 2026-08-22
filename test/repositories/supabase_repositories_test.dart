import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:setu/repositories/supabase_user_repository.dart';
import 'package:setu/repositories/supabase_family_circle_repository.dart';
import 'package:setu/repositories/supabase_daily_log_repository.dart';
import 'package:setu/repositories/supabase_task_repository.dart';
import 'package:setu/models/user_model.dart';
import 'package:setu/models/daily_log.dart';
import 'package:setu/models/task_model.dart';
import 'package:setu/models/family_circle.dart';

void main() {
  setUpAll(() async {
    try {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
      );
    } catch (_) {}
  });

  group('Supabase Repositories Initializations & Error Handling Tests', () {
    test('SupabaseUserRepository instantiates and handles missing user gracefully', () async {
      final userRepo = SupabaseUserRepository();
      expect(userRepo, isNotNull);

      // Non-existent user returns null gracefully
      final user = await userRepo.getUser('non_existent_id');
      expect(user, isNull);
    });

    test('SupabaseFamilyCircleRepository instantiates and handles missing circle gracefully', () async {
      final circleRepo = SupabaseFamilyCircleRepository();
      expect(circleRepo, isNotNull);

      final circle = await circleRepo.getFamilyCircle('non_existent_id');
      expect(circle, isNull);
    });

    test('SupabaseDailyLogRepository instantiates and handles empty log query gracefully', () async {
      final logRepo = SupabaseDailyLogRepository();
      expect(logRepo, isNotNull);

      final logs = await logRepo.getDailyLogs('non_existent_id');
      expect(logs, isEmpty);
    });

    test('SupabaseDailyLogRepository addDailyLog throws UnsupportedError', () {
      final logRepo = SupabaseDailyLogRepository();
      final log = DailyLog(
        date: '2026-08-22',
        status: 'green',
        transcript: 'test',
        summary: 'test',
        flaggedConcerns: [],
      );

      expect(
        () => logRepo.addDailyLog('circle_id', log),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('SupabaseTaskRepository instantiates and handles empty task query gracefully', () async {
      final taskRepo = SupabaseTaskRepository();
      expect(taskRepo, isNotNull);

      final tasks = await taskRepo.getTasks('non_existent_id');
      expect(tasks, isEmpty);
    });
  });
}
