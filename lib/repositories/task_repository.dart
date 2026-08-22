import '../models/task_model.dart';

abstract class TaskRepository {
  Future<List<TaskModel>> getTasks(String circleId);
  Stream<List<TaskModel>> watchTasks(String circleId);
  Future<void> addTask(String circleId, TaskModel task);
}

class MockTaskRepository implements TaskRepository {
  final Map<String, List<TaskModel>> _tasks = {};

  @override
  Future<List<TaskModel>> getTasks(String circleId) async {
    await Future.delayed(const Duration(seconds: 1));
    return _tasks[circleId] ?? [];
  }

  @override
  Stream<List<TaskModel>> watchTasks(String circleId) async* {
    yield _tasks[circleId] ?? [];
  }

  @override
  Future<void> addTask(String circleId, TaskModel task) async {
    await Future.delayed(const Duration(seconds: 1));
    if (!_tasks.containsKey(circleId)) {
      _tasks[circleId] = [];
    }
    _tasks[circleId]!.add(task);
  }
}
