import '../models/daily_log.dart';

abstract class DailyLogRepository {
  Future<List<DailyLog>> getDailyLogs(String circleId);
  Stream<List<DailyLog>> watchDailyLogs(String circleId);
  Future<void> addDailyLog(String circleId, DailyLog log);
}

class MockDailyLogRepository implements DailyLogRepository {
  final Map<String, List<DailyLog>> _logs = {};

  @override
  Future<List<DailyLog>> getDailyLogs(String circleId) async {
    await Future.delayed(const Duration(seconds: 1));
    return _logs[circleId] ?? [];
  }

  @override
  Stream<List<DailyLog>> watchDailyLogs(String circleId) async* {
    yield _logs[circleId] ?? [];
  }

  @override
  Future<void> addDailyLog(String circleId, DailyLog log) async {
    await Future.delayed(const Duration(seconds: 1));
    if (!_logs.containsKey(circleId)) {
      _logs[circleId] = [];
    }
    _logs[circleId]!.add(log);
  }
}
