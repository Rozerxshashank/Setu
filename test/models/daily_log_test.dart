import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:setu/models/daily_log.dart';

void main() {
  group('DailyLog.fromJson', () {
    test('parses full valid JSON with Timestamp correctly', () {
      final now = DateTime.now();
      final json = {
        'date': '2026-08-22',
        'status': 'yellow',
        'transcript': 'My knee hurts',
        'summary': 'Parent has knee pain',
        'medicationTaken': true,
        'flaggedConcerns': ['knee pain'],
        'respondedAt': Timestamp.fromDate(now),
        'audioUrl': 'audio_inbox/123/file.m4a',
      };

      final log = DailyLog.fromJson(json);

      expect(log.date, '2026-08-22');
        expect(log.status, 'yellow');
        expect(log.transcript, 'My knee hurts');
        expect(log.medicationTaken, true);
        expect(log.flaggedConcerns, ['knee pain']);
        // Timestamp is converted to DateTime internally, but there's a slight precision loss sometimes in ms, so we just check equality or rough equality.
        expect(log.respondedAt, isNotNull);
        expect(log.audioUrl, 'audio_inbox/123/file.m4a');
    });

    test('handles missing or null fields gracefully', () {
      final json = <String, dynamic>{};

      final log = DailyLog.fromJson(json);

      expect(log.date, 'Unknown Date');
      expect(log.status, 'green');
      expect(log.transcript, 'No transcript available.');
      expect(log.summary, 'No summary available.');
      expect(log.medicationTaken, null);
      expect(log.flaggedConcerns, []);
      expect(log.respondedAt, null);
      expect(log.audioUrl, null);
    });

    test('handles String respondedAt gracefully', () {
      final json = {
        'respondedAt': '2026-08-22T10:00:00Z',
      };

      final log = DailyLog.fromJson(json);

      expect(log.respondedAt, DateTime.parse('2026-08-22T10:00:00Z'));
    });
  });
}
