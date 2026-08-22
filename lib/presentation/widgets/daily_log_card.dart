import 'package:flutter/material.dart';
import '../../models/daily_log.dart';
import 'daily_log_detail_sheet.dart';

class DailyLogCard extends StatelessWidget {
  final DailyLog log;

  const DailyLogCard({super.key, required this.log});

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
    final statusLabel = _getStatusLabel();
    return Semantics(
      label: 'Check-in on ${log.date}. Status: $statusLabel. ${log.flaggedConcerns.isNotEmpty ? "${log.flaggedConcerns.length} flagged concerns." : ""} ${log.medicationTaken == true ? "Medication taken." : log.medicationTaken == false ? "Medication missed." : ""}',
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        elevation: 2,
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => DailyLogDetailSheet(log: log),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log.date,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Row(
                      children: [
                        Icon(_getStatusIcon(), color: _getStatusColor(), size: 20, semanticLabel: 'Status icon'),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  log.summary,
                  style: const TextStyle(fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    if (log.medicationTaken != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.medical_services,
                            size: 16,
                            color: log.medicationTaken! ? Colors.green : Colors.red,
                            semanticLabel: 'Medication icon'
                          ),
                          const SizedBox(width: 4),
                          Text(
                            log.medicationTaken! ? 'Medication Taken' : 'Medication Missed',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    if (log.flaggedConcerns.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flag, size: 16, color: Colors.orange, semanticLabel: 'Flag icon'),
                          const SizedBox(width: 4),
                          Text(
                            '${log.flaggedConcerns.length} concern(s)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
