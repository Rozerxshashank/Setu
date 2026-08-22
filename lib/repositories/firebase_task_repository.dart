import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import 'task_repository.dart';

class FirebaseTaskRepository implements TaskRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<TaskModel>> getTasks(String circleId) async {
    final snapshot = await _db
        .collection('familyCircles')
        .doc(circleId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .get();
        
    return snapshot.docs.map((doc) => TaskModel.fromJson(doc.data())).toList();
  }

  @override
  Stream<List<TaskModel>> watchTasks(String circleId) {
    return _db
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
    final docRef = _db
        .collection('familyCircles')
        .doc(circleId)
        .collection('tasks')
        .doc(task.taskId);
        
    await docRef.set(task.toJson());
  }
}
