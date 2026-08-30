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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => DailyLogDetailSheet(log: log),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log.date,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(), color: _getStatusColor(), size: 16, semanticLabel: 'Status icon'),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: _getStatusColor(),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  log.summary,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (log.medicationTaken != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 14,
                              color: log.medicationTaken! ? Colors.green : Colors.red,
                              semanticLabel: 'Medication icon'
                            ),
                            const SizedBox(width: 6),
                            Text(
                              log.medicationTaken! ? 'Meds Taken' : 'Meds Missed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (log.flaggedConcerns.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange.shade200),
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flag_outlined, size: 14, color: Colors.orange.shade800, semanticLabel: 'Flag icon'),
                            const SizedBox(width: 6),
                            Text(
                              '${log.flaggedConcerns.length} concern(s)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
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
