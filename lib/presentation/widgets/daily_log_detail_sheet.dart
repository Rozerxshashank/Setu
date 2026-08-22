import 'package:flutter/material.dart';
import '../../models/daily_log.dart';

class DailyLogDetailSheet extends StatelessWidget {
  final DailyLog log;

  const DailyLogDetailSheet({super.key, required this.log});

  Color _getStatusColor() {
    switch (log.status) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'grey':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getStatusIcon() {
    switch (log.status) {
      case 'green':
        return Icons.check_circle;
      case 'yellow':
        return Icons.warning_amber_rounded;
      case 'red':
        return Icons.error;
      case 'grey':
        return Icons.radio_button_unchecked;
      default:
        return Icons.info;
    }
  }

  String _getStatusLabel() {
    switch (log.status) {
      case 'green':
        return 'OK';
      case 'yellow':
        return 'Needs Attention';
      case 'red':
        return 'Urgent Attention';
      case 'grey':
        return 'Missed';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      // Set a max height so it's a scrollable bottom sheet
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Check-in for ${log.date}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Semantics(
                button: true,
                label: 'Close',
                child: IconButton(
                  icon: const Icon(Icons.close, semanticLabel: 'Close icon'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  
                  // Status
                  Semantics(
                    label: 'Status: ${_getStatusLabel()}',
                    child: Row(
                      children: [
                        Icon(_getStatusIcon(), color: _getStatusColor(), size: 28, semanticLabel: 'Status icon'),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusLabel(),
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // AI Summary
                  Semantics(
                    label: 'AI-generated summary: ${log.summary}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'AI-generated summary based on the voice message',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            log.summary,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Flagged Concerns
                  if (log.flaggedConcerns.isNotEmpty) ...[
                    Semantics(
                      header: true,
                      child: const Text(
                        'Flagged concerns extracted from response',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...log.flaggedConcerns.map((concern) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Semantics(
                        label: 'Concern: $concern',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(concern, style: const TextStyle(fontSize: 16))),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Medication
                  const Text(
                    'Medication',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        log.medicationTaken == true
                            ? Icons.check_circle
                            : log.medicationTaken == false
                                ? Icons.cancel
                                : Icons.help_outline,
                        color: log.medicationTaken == true
                            ? Colors.green
                            : log.medicationTaken == false
                                ? Colors.red
                                : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        log.medicationTaken == true
                            ? 'Taken'
                            : log.medicationTaken == false
                                ? 'Not taken'
                                : 'Not mentioned',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Raw Transcript
                  Semantics(
                    label: 'Original transcript: ${log.transcript}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Original transcript',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            log.transcript,
                            style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
