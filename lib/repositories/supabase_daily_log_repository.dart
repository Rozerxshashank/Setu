import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_log.dart';
import 'daily_log_repository.dart';

class SupabaseDailyLogRepository implements DailyLogRepository {
  final SupabaseClient _supabase;

  SupabaseDailyLogRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  DailyLog _mapRowToDailyLog(Map<String, dynamic> row) {
    DateTime? parsedRespondedAt;
    if (row['responded_at'] != null) {
      parsedRespondedAt = DateTime.tryParse(row['responded_at'] as String);
    }

    return DailyLog(
      date: row['date'] as String? ?? 'Unknown Date',
      status: row['status'] as String? ?? 'green',
      transcript: row['transcript'] as String? ?? '',
      summary: row['summary'] as String? ?? '',
      medicationTaken: row['medication_taken'] as bool?,
      flaggedConcerns: row['flagged_concerns'] != null
          ? List<String>.from(row['flagged_concerns'])
          : [],
      respondedAt: parsedRespondedAt,
      audioUrl: row['audio_url'] as String?,
    );
  }

  @override
  Future<List<DailyLog>> getDailyLogs(String circleId) async {
    try {
      final response = await _supabase
          .from('daily_logs')
          .select('*')
          .eq('circle_id', circleId)
          .order('date', ascending: false);

      return (response as List)
          .map((row) => _mapRowToDailyLog(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<DailyLog>> watchDailyLogs(String circleId) {
    return _supabase
        .from('daily_logs')
        .stream(primaryKey: ['id'])
        .eq('circle_id', circleId)
        .order('date', ascending: false)
        .map((rows) => rows.map(_mapRowToDailyLog).toList());
  }

  @override
  Future<void> addDailyLog(String circleId, DailyLog log) async {
    throw UnsupportedError("Clients cannot directly write daily logs.");
  }
}
