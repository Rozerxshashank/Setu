import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class AudioRecordingService {
  Future<bool> hasPermission();
  Future<void> startRecording();
  Future<String?> stopRecording();
  Future<void> cancelRecording();
  Future<void> dispose();
}

class LocalAudioRecordingService implements AudioRecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentPath;

  @override
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  @override
  Future<void> startRecording() async {
    if (await hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      _currentPath =
          '${dir.path}/elder_record_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(const RecordConfig(), path: _currentPath!);
    } else {
      throw Exception('Microphone permission denied.');
    }
  }

  @override
  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    return path;
  }

  @override
  Future<void> cancelRecording() async {
    await _audioRecorder.stop();
  }

  @override
  Future<void> dispose() async {
    await _audioRecorder.dispose();
  }
}
