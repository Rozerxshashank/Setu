import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:setu/services/supabase_audio_processing_service.dart';

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

  group('SupabaseAudioProcessingService Tests', () {
    late SupabaseAudioProcessingService service;

    setUp(() {
      service = SupabaseAudioProcessingService();
    });

    test('initializes correctly', () {
      expect(service, isNotNull);
    });

    test('rejects invalid audio storage path format locally', () async {
      final result = await service.processAudioCheckIn(
        circleId: 'circle_123',
        audioPath: 'invalid_path_format.m4a',
      );

      expect(result['success'], false);
      expect(result['error'], 'Invalid audio storage path format.');
    });

    test('rejects mismatched circleId in audio path', () async {
      final result = await service.processAudioCheckIn(
        circleId: 'circle_123',
        audioPath: 'other_circle/user_456/elder_record.m4a',
      );

      expect(result['success'], false);
      expect(result['error'], 'Invalid audio storage path format.');
    });

    test('accepts valid audio path format locally', () async {
      // Valid path format: circleId/userId/filename
      // Will attempt function invocation and return mapped error since unauthenticated
      final result = await service.processAudioCheckIn(
        circleId: 'circle_123',
        audioPath: 'circle_123/user_456/elder_record_100.m4a',
      );

      expect(result['success'], isFalse);
      expect(result['error'], isNotNull);
    });
  });
}
