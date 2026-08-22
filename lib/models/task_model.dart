import 'package:cloud_firestore/cloud_firestore.dart';

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
    return TaskModel(
      taskId: json['taskId'] as String,
      createdBy: json['createdBy'] as String,
      text: json['text'] as String,
      status: json['status'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      deliveredInCheckInDate: json['deliveredInCheckInDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'createdBy': createdBy,
      'text': text,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveredInCheckInDate': deliveredInCheckInDate,
    };
  }
}
