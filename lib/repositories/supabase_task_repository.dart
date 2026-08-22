import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import 'task_repository.dart';

class SupabaseTaskRepository implements TaskRepository {
  final SupabaseClient _supabase;

  SupabaseTaskRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  TaskModel _mapRowToTask(Map<String, dynamic> row) {
    DateTime createdAtDate = DateTime.now();
    if (row['created_at'] != null) {
      createdAtDate = DateTime.tryParse(row['created_at'] as String) ?? DateTime.now();
    }

    return TaskModel(
      taskId: row['id'] as String,
      createdBy: row['created_by'] as String? ?? 'unknown',
      text: row['text'] as String? ?? '',
      status: row['status'] as String? ?? 'pending',
      createdAt: createdAtDate,
      deliveredInCheckInDate: row['delivered_in_checkin_date'] as String?,
    );
  }

  @override
  Future<List<TaskModel>> getTasks(String circleId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select('*')
          .eq('circle_id', circleId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => _mapRowToTask(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<TaskModel>> watchTasks(String circleId) {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('circle_id', circleId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_mapRowToTask).toList());
  }

  @override
  Future<void> addTask(String circleId, TaskModel task) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Must be logged in to add tasks.');
    }

    await _supabase.from('tasks').insert({
      'circle_id': circleId,
      'created_by': currentUserId,
      'text': task.text,
      'status': 'pending', // Strictly force pending status
    });
  }
}
