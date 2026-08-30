import 'package:flutter/material.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/audio_recording_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../services/supabase_audio_processing_service.dart';
import '../../models/task_model.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/supabase_task_repository.dart';

class ElderViewScreen extends StatefulWidget {
  final TaskRepository? taskRepo;
  const ElderViewScreen({super.key, this.taskRepo});

  @override
  State<ElderViewScreen> createState() => _ElderViewScreenState();
}

class _ElderViewScreenState extends State<ElderViewScreen> {
  final AudioRecordingService _recordingService = LocalAudioRecordingService();
  late final TaskRepository _taskRepo;
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _isUploading = false;
  bool _isProcessing = false;
  String? _recordingPath;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _taskRepo = widget.taskRepo ?? SupabaseTaskRepository();
  }

  @override
  void dispose() {
    _recordingService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() => _errorMessage = null);
    try {
      await _recordingService.startRecording();
      setState(() {
        _isRecording = true;
        _hasRecorded = false;
      });
    } catch (e) {
      setState(
        () => _errorMessage = 'Unable to access the microphone. Please check permissions.',
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recordingService.stopRecording();
      setState(() {
        _isRecording = false;
        if (path != null) {
          _hasRecorded = true;
          _recordingPath = path;
        } else {
          _errorMessage = 'Recording was empty. Please try speaking again.';
        }
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = 'Something went wrong while stopping the recording. Please try again.';
      });
    }
  }

  Future<void> _cancelRecording() async {
    await _recordingService.cancelRecording();
    setState(() {
      _isRecording = false;
      _hasRecorded = false;
    });
  }

  Future<void> _sendRecording() async {
    if (_recordingPath == null || _isUploading || _isProcessing) return;

    setState(() {
      _isUploading = true;
      _isProcessing = false;
      _errorMessage = null;
    });

    try {
      const circleId = 'demo_circle_123';
      const userId = 'demo_user_123';

      final file = File(_recordingPath!);
      final storageService = SupabaseStorageService();
      final result = await storageService.uploadAudio(
        circleId: circleId,
        userId: userId,
        audioFile: file,
      );
      final storagePath = result['storagePath']!;

      setState(() {
        _isUploading = false;
        _isProcessing = true;
      });

      final audioProcService = SupabaseAudioProcessingService();
      final procResult = await audioProcService.processAudioCheckIn(
        circleId: circleId,
        audioPath: storagePath,
      );

      if (procResult['success'] != true) {
        throw Exception(procResult['error'] ?? 'Unable to process your message right now.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Message sent successfully! Your family will be notified.',
              style: TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMessage = msg.contains('Unable to process') || msg.contains('temporarily unavailable') || msg.contains('access') || msg.contains('login')
              ? msg
              : 'Unable to process the recording right now. [Demo Mode]';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _hasRecorded = false;
          _isUploading = false;
          _isProcessing = false;
          _recordingPath = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elder Check-in'),
        backgroundColor: Colors.blue.shade100,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mock Elder Info & Prompt
              Semantics(
                header: true,
                child: const Text(
                  'Good morning Amma. How are you feeling today?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Dynamic Tasks/Reminders
              StreamBuilder<List<TaskModel>>(
                stream: _taskRepo.watchTasks('demo_circle_123'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  
                  final pendingTasks = snapshot.data!.where((t) => t.status == 'pending').toList();
                  if (pendingTasks.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.assignment, size: 40, color: Colors.brown),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Also:',
                                style: TextStyle(fontSize: 22, color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...pendingTasks.map((task) => Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '• ${task.text}',
                            style: const TextStyle(fontSize: 22, color: Colors.black87),
                          ),
                        )),
                      ],
                    ),
                  );
                },
              ),

              Semantics(
                label: "Instruction",
                child: const Text(
                  'Please send a voice message telling your family how you are doing.',
                  style: TextStyle(fontSize: 24, color: Colors.black87),
                ),
              ),
              const Spacer(),

              if (_errorMessage != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              if (!_isRecording && !_hasRecorded)
                Semantics(
                  button: true,
                  label: "Start Recording Button",
                  child: ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.mic, size: 48, semanticLabel: 'Microphone icon'),
                    label: const Text(
                      'Start Recording',
                      style: TextStyle(fontSize: 28),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              if (_isRecording)
                Semantics(
                  liveRegion: true,
                  label: "Currently recording",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radio_button_checked,
                            color: Colors.red,
                            size: 36,
                            semanticLabel: 'Red recording indicator',
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Recording...',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        button: true,
                        label: "Stop Recording Button",
                        child: ElevatedButton.icon(
                          onPressed: _stopRecording,
                          icon: const Icon(Icons.stop, size: 48, semanticLabel: 'Stop icon'),
                          label: const Text('Stop', style: TextStyle(fontSize: 28)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_hasRecorded && !_isRecording)
                Semantics(
                  liveRegion: true,
                  label: (_isUploading || _isProcessing)
                      ? (_isUploading ? "Uploading message" : "Processing message")
                      : "Message ready to send",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            (_isUploading || _isProcessing) ? Icons.cloud_upload : Icons.check_circle, 
                            color: (_isUploading || _isProcessing) ? Colors.blue : Colors.green, 
                            size: 36, 
                            semanticLabel: (_isUploading || _isProcessing) ? 'Upload icon' : 'Success icon'
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isUploading
                                ? 'Uploading...'
                                : (_isProcessing ? 'Processing...' : 'Message ready'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: (_isUploading || _isProcessing) ? Colors.blue : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        button: true,
                        label: "Send message button",
                        child: ElevatedButton.icon(
                          onPressed: (_isUploading || _isProcessing) ? null : _sendRecording,
                          icon: const Icon(Icons.send, size: 40, semanticLabel: 'Send icon'),
                          label: Text(
                            _isUploading
                                ? 'Uploading...'
                                : (_isProcessing ? 'Processing...' : 'Send to Family'),
                            style: const TextStyle(fontSize: 28),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_isUploading && !_isProcessing)
                        Semantics(
                          button: true,
                          label: "Discard and record again button",
                          child: OutlinedButton.icon(
                            onPressed: _cancelRecording,
                            icon: const Icon(Icons.refresh, size: 32, semanticLabel: 'Refresh icon'),
                            label: const Text(
                              'Record again',
                              style: TextStyle(fontSize: 24),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
