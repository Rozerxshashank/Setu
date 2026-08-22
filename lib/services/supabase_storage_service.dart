import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  final _storage = Supabase.instance.client.storage.from('audio_inbox');
  
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  
  // Mapping extensions to allowed MIME types
  static const Map<String, String> allowedMimeTypes = {
    'm4a': 'audio/x-m4a',
    'mp4': 'audio/mp4',
    'mp3': 'audio/mpeg',
    'mpeg': 'audio/mpeg',
    'wav': 'audio/wav',
  };

  Future<Map<String, String>> uploadAudio({
    required String circleId,
    required String userId,
    required File audioFile,
  }) async {
    // 1. Check file size
    final length = await audioFile.length();
    if (length > maxFileSize) {
      throw Exception('Audio file is too large.');
    }

    // 2. Check MIME type/extension
    final extension = audioFile.path.split('.').last.toLowerCase();
    if (!allowedMimeTypes.containsKey(extension)) {
      throw Exception('Unsupported audio format.');
    }
    
    final mimeType = allowedMimeTypes[extension]!;
    final fileName = 'elder_record_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storagePath = '$circleId/$userId/$fileName';

    try {
      // 3. Upload to Supabase
      final publicRef = await _storage.upload(
        storagePath,
        audioFile,
        fileOptions: FileOptions(contentType: mimeType),
      );
      
      return {
        'storagePath': storagePath,
        'publicRef': publicRef,
      };
    } catch (e) {
      throw Exception('Upload failed. Please try again.');
    }
  }
}
