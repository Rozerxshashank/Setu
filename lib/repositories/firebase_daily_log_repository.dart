import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_log.dart';
import 'daily_log_repository.dart';

class FirebaseDailyLogRepository implements DailyLogRepository {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DailyLog>> getDailyLogs(String circleId) async {
    final db = _firestore;
    if (db == null) return [];
    final snapshot = await db
        .collection('familyCircles')
        .doc(circleId)
        .collection('dailyLogs')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => DailyLog.fromJson(doc.data())).toList();
  }

  @override
  Stream<List<DailyLog>> watchDailyLogs(String circleId) {
    final db = _firestore;
    if (db == null) return Stream.value([]);
    return db
        .collection('familyCircles')
        .doc(circleId)
        .collection('dailyLogs')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => DailyLog.fromJson(doc.data())).toList());
  }

  @override
  Future<void> addDailyLog(String circleId, DailyLog log) async {
    throw UnsupportedError("Clients cannot directly write daily logs.");
  }
}
