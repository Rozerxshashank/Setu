import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import 'task_repository.dart';

class FirebaseTaskRepository implements TaskRepository {
  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TaskModel>> getTasks(String circleId) async {
    final db = _db;
    if (db == null) return [];
    final snapshot = await db
        .collection('familyCircles')
        .doc(circleId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .get();
        
    return snapshot.docs.map((doc) => TaskModel.fromJson(doc.data())).toList();
  }

  @override
  Stream<List<TaskModel>> watchTasks(String circleId) {
    final db = _db;
    if (db == null) return Stream.value([]);
    return db
        .collection('familyCircles')
        .doc(circleId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromJson(doc.data()))
            .toList());
  }

  @override
  Future<void> addTask(String circleId, TaskModel task) async {
    final db = _db;
    if (db == null) return;
    final docRef = db
        .collection('familyCircles')
        .doc(circleId)
        .collection('tasks')
        .doc(task.taskId);
        
    await docRef.set(task.toJson());
  }
}
