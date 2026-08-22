import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu/services/supabase_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('SupabaseStorageService Tests', () {
    late SupabaseStorageService storageService;

    setUp(() {
      storageService = SupabaseStorageService();
    });

    test('initializes correctly', () {
      expect(storageService, isNotNull);
    });

    test('rejects unsupported file formats', () async {
      // Create a dummy file with unsupported extension
      final file = File('dummy.txt');
      await file.writeAsString('test');

      expect(
        () => storageService.uploadAudio(
          circleId: 'circle_1',
          userId: 'user_1',
          audioFile: file,
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unsupported audio format.'))),
      );

      if (await file.exists()) {
        await file.delete();
      }
    });

    test('rejects files larger than 5MB', () async {
      final file = File('large_audio.m4a');
      // Create a sparse file of 6MB
      final raf = await file.open(mode: FileMode.write);
      await raf.setPosition(6 * 1024 * 1024);
      await raf.writeByte(0);
      await raf.close();

      expect(
        () => storageService.uploadAudio(
          circleId: 'circle_1',
          userId: 'user_1',
          audioFile: file,
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Audio file is too large.'))),
      );

      if (await file.exists()) {
        await file.delete();
      }
    });
  });
}
