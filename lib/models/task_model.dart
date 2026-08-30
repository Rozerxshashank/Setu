class TaskModel {
  final String taskId;
  final String createdBy;
  final String text;
  final String status; // "pending" | "delivered" | "acknowledged"
  final DateTime createdAt;
  final String? deliveredInCheckInDate;

  TaskModel({
    required this.taskId,
    required this.createdBy,
    required this.text,
    required this.status,
    required this.createdAt,
    this.deliveredInCheckInDate,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt = DateTime.now();
    if (json['createdAt'] != null && json['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now();
    }

    return TaskModel(
      taskId: json['taskId'] as String,
      createdBy: json['createdBy'] as String,
      text: json['text'] as String,
      status: json['status'] as String,
      createdAt: parsedCreatedAt,
      deliveredInCheckInDate: json['deliveredInCheckInDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'createdBy': createdBy,
      'text': text,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'deliveredInCheckInDate': deliveredInCheckInDate,
    };
  }
}
