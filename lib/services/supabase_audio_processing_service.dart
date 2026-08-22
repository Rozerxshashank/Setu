import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAudioProcessingService {
  final SupabaseClient _supabase;

  SupabaseAudioProcessingService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  Future<Map<String, dynamic>> processAudioCheckIn({
    required String circleId,
    required String audioPath,
  }) async {
    // 1. Validate audio path format: circleId/userId/filename or audio_inbox/circleId/userId/filename
    final normalizedPath = audioPath.startsWith('audio_inbox/')
        ? audioPath.substring('audio_inbox/'.length)
        : audioPath;

    final parts = normalizedPath.split('/');
    if (parts.length < 3 || parts[0] != circleId || parts[1].isEmpty || parts[2].isEmpty) {
      return {
        'success': false,
        'error': 'Invalid audio storage path format.',
      };
    }

    try {
      final response = await _supabase.functions.invoke(
        'process-audio-checkin',
        body: {
          'circle_id': circleId,
          'audio_path': normalizedPath,
        },
      );

      if (response.status == 200 || response.status == 201) {
        final data = response.data as Map<String, dynamic>? ?? {};
        if (data['success'] == true) {
          return {
            'success': true,
            'daily_log_id': data['log_id'] ?? data['daily_log_id'],
          };
        } else {
          return {
            'success': false,
            'error': _mapErrorMessage(response.status, data['error'] as String?),
          };
        }
      } else {
        final data = response.data is Map ? response.data as Map : {};
        return {
          'success': false,
          'error': _mapErrorMessage(response.status, data['error'] as String?),
        };
      }
    } on FunctionException catch (e) {
      return {
        'success': false,
        'error': _mapErrorMessage(e.status, e.reasonPhrase),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Unable to process your message right now.',
      };
    }
  }

  String _mapErrorMessage(int status, String? serverMessage) {
    if (status == 401) return 'Please login again.';
    if (status == 403) return 'You do not have access to this family circle.';
    if (status == 404) return 'Audio could not be found.';
    if (status == 429 || status == 503) {
      return 'AI processing is temporarily unavailable. Please try again later.';
    }
    if (serverMessage != null && serverMessage.contains('temporarily unavailable')) {
      return 'AI processing is temporarily unavailable. Please try again later.';
    }
    return 'Unable to process your message right now.';
  }
}
