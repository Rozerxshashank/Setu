class DailyLog {
  final String date; // "2026-08-22"
  final String status; // "green" | "yellow" | "red" | "grey"
  final String transcript;
  final String summary;
  final bool? medicationTaken;
  final List<String> flaggedConcerns;
  final DateTime? respondedAt;
  final String? audioUrl;

  DailyLog({
    required this.date,
    required this.status,
    required this.transcript,
    required this.summary,
    this.medicationTaken,
    required this.flaggedConcerns,
    this.respondedAt,
    this.audioUrl,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    DateTime? parsedRespondedAt;
    if (json['respondedAt'] != null && json['respondedAt'] is String) {
      parsedRespondedAt = DateTime.tryParse(json['respondedAt'] as String);
    }

    return DailyLog(
      date: json['date'] as String? ?? 'Unknown Date',
      status: json['status'] as String? ?? 'green',
      transcript: json['transcript'] as String? ?? 'No transcript available.',
      summary: json['summary'] as String? ?? 'No summary available.',
      medicationTaken: json['medicationTaken'] as bool?,
      flaggedConcerns: json['flaggedConcerns'] != null 
          ? List<String>.from(json['flaggedConcerns']) 
          : [],
      respondedAt: parsedRespondedAt,
      audioUrl: json['audioUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'status': status,
      'transcript': transcript,
      'summary': summary,
      'medicationTaken': medicationTaken,
      'flaggedConcerns': flaggedConcerns,
      'respondedAt': respondedAt?.toIso8601String(),
      'audioUrl': audioUrl,
    };
  }
}
