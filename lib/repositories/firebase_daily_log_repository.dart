import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_log.dart';
import 'daily_log_repository.dart';

class FirebaseDailyLogRepository implements DailyLogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<DailyLog>> getDailyLogs(String circleId) async {
    final snapshot = await _firestore
        .collection('familyCircles')
        .doc(circleId)
        .collection('dailyLogs')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => DailyLog.fromJson(doc.data())).toList();
  }

  @override
  Stream<List<DailyLog>> watchDailyLogs(String circleId) {
    return _firestore
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
    // Client-side writes to daily logs are blocked by rules.
    // This method exists in the interface but should not be called by the client in prod.
    throw UnsupportedError("Clients cannot directly write daily logs.");
  }
}
