import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu/models/daily_log.dart';
import 'package:setu/models/user_model.dart';
import 'package:setu/presentation/screens/home_screen.dart';
import 'package:setu/repositories/daily_log_repository.dart';
import 'package:setu/repositories/user_repository.dart';
import 'package:setu/repositories/task_repository.dart';
import 'package:setu/models/task_model.dart';

class MockUserRepositoryForTest implements UserRepository {
  final StreamController<UserModel?> _controller = StreamController<UserModel?>.broadcast();
  
  void emit(UserModel? user) {
    _controller.add(user);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Future<void> createUser(UserModel user) async {}
  @override
  Future<UserModel?> getUser(String userId) async => null;
  @override
  Future<void> updateUser(UserModel user) async {}
  @override
  Stream<UserModel?> watchUser(String userId) => _controller.stream;
}

class MockDailyLogRepositoryForTest implements DailyLogRepository {
  final StreamController<List<DailyLog>> _controller = StreamController<List<DailyLog>>.broadcast();

  void emit(List<DailyLog> logs) {
    _controller.add(logs);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Future<void> addDailyLog(String circleId, DailyLog log) async {}
  @override
  Future<List<DailyLog>> getDailyLogs(String circleId) async => [];
  @override
  Stream<List<DailyLog>> watchDailyLogs(String circleId) => _controller.stream;
}

class MockTaskRepositoryForTest implements TaskRepository {
  @override
  Future<List<TaskModel>> getTasks(String circleId) async => [];
  @override
  Stream<List<TaskModel>> watchTasks(String circleId) => Stream.value([]);
  @override
  Future<void> addTask(String circleId, TaskModel task) async {}
}

void main() {
  group('HomeScreen Dashboard Tests', () {
    late MockUserRepositoryForTest mockUserRepo;
    late MockDailyLogRepositoryForTest mockLogRepo;
    late MockTaskRepositoryForTest mockTaskRepo;

    setUp(() {
      mockUserRepo = MockUserRepositoryForTest();
      mockLogRepo = MockDailyLogRepositoryForTest();
      mockTaskRepo = MockTaskRepositoryForTest();
    });

    Widget createHomeScreen() {
      return MaterialApp(
        home: HomeScreen(
          testUid: 'test_user_123',
          userRepo: mockUserRepo,
          logRepo: mockLogRepo,
          taskRepo: mockTaskRepo,
        ),
      );
    }

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows zero circles empty state', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      
      mockUserRepo.emit(UserModel(userId: 'test_user_123', name: 'Test', phoneNumber: '123', circleIds: [], fcmTokens: []));
      await tester.pumpAndSettle();

      expect(find.text("You're not part of a Family Circle yet."), findsOneWidget);
    });

    testWidgets('shows loading check-ins state', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      
      mockUserRepo.emit(UserModel(userId: 'test_user_123', name: 'Test', phoneNumber: '123', circleIds: ['circle_1'], fcmTokens: []));
      await tester.pump(); // Pump once to process user stream
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state for check-ins', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      
      mockUserRepo.emit(UserModel(userId: 'test_user_123', name: 'Test', phoneNumber: '123', circleIds: ['circle_1'], fcmTokens: []));
      await tester.pump();
      
      mockLogRepo.emitError(Exception('Network error'));
      await tester.pumpAndSettle();

      expect(
          find.text('Unable to load check-ins. Please check your network and try again.'),
          findsOneWidget);
    });

    testWidgets('shows empty logs state', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      
      mockUserRepo.emit(UserModel(userId: 'test_user_123', name: 'Test', phoneNumber: '123', circleIds: ['circle_1'], fcmTokens: []));
      await tester.pump();
      
      mockLogRepo.emit([]);
      await tester.pumpAndSettle();

      expect(find.text('No check-ins yet'), findsOneWidget);
    });

    testWidgets('renders daily logs chronologically', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      
      mockUserRepo.emit(UserModel(userId: 'test_user_123', name: 'Test', phoneNumber: '123', circleIds: ['circle_1'], fcmTokens: []));
      await tester.pump();
      
      mockLogRepo.emit([
        DailyLog(date: '2026-08-22', status: 'red', transcript: 'raw text 1', summary: 'AI summary 1', flaggedConcerns: ['pain']),
        DailyLog(date: '2026-08-21', status: 'green', transcript: 'raw text 2', summary: 'AI summary 2', flaggedConcerns: []),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('2026-08-22'), findsOneWidget);
      expect(find.text('2026-08-21'), findsOneWidget);
      expect(find.text('Urgent Attention'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('1 concern(s)'), findsOneWidget);
    });

    testWidgets('detail view opens on tap', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      
      mockUserRepo.emit(UserModel(userId: 'test_user_123', name: 'Test', phoneNumber: '123', circleIds: ['circle_1'], fcmTokens: []));
      await tester.pump();
      
      mockLogRepo.emit([
        DailyLog(date: '2026-08-22', status: 'yellow', transcript: 'Original transcript text', summary: 'AI summary text', flaggedConcerns: ['knee pain']),
      ]);
      await tester.pumpAndSettle();

      // Tap the card
      await tester.tap(find.text('2026-08-22'));
      await tester.pumpAndSettle(); // Wait for bottom sheet animation

      expect(find.text('Check-in for 2026-08-22'), findsOneWidget);
      expect(find.text('AI-generated summary based on the voice message'), findsOneWidget);
      expect(find.text('Original transcript'), findsOneWidget);
      expect(find.text('Original transcript text'), findsOneWidget);
      expect(find.text('knee pain'), findsOneWidget);
    });
  });
}
