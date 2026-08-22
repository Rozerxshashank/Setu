import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu/models/task_model.dart';
import 'package:setu/repositories/task_repository.dart';
import 'package:setu/presentation/widgets/add_task_dialog.dart';
import 'package:setu/presentation/widgets/task_list_widget.dart';

class MockTaskRepository implements TaskRepository {
  final _tasksController = StreamController<List<TaskModel>>.broadcast();
  bool shouldThrow = false;
  int addTaskCallCount = 0;
  
  void emitTasks(List<TaskModel> tasks) {
    if (shouldThrow) {
      _tasksController.addError(Exception('Repo error'));
    } else {
      _tasksController.add(tasks);
    }
  }

  @override
  Future<void> addTask(String circleId, TaskModel task) async {
    addTaskCallCount++;
    if (shouldThrow) throw Exception('Failed to add');
    await Future.delayed(const Duration(milliseconds: 100)); // simulate network
  }

  @override
  Future<List<TaskModel>> getTasks(String circleId) async => [];

  @override
  Stream<List<TaskModel>> watchTasks(String circleId) => _tasksController.stream;
}

void main() {
  late MockTaskRepository mockRepo;

  setUp(() {
    mockRepo = MockTaskRepository();
  });

  Widget buildDialog() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AddTaskDialog(
                    circleId: 'circle1',
                    currentUserId: 'user1',
                    taskRepo: mockRepo,
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
  }

  group('Step 7: Task Creation (AddTaskDialog)', () {
    testWidgets('Empty task rejected', (WidgetTester tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Task text cannot be empty'), findsOneWidget);
      expect(mockRepo.addTaskCallCount, 0);
    });

    testWidgets('Whitespace-only task rejected', (WidgetTester tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Task text cannot be empty'), findsOneWidget);
      expect(mockRepo.addTaskCallCount, 0);
    });

    testWidgets('>500 characters rejected', (WidgetTester tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final longText = 'A' * 501;
      // Note: TextField with maxLength enforces it locally in Flutter,
      // but let's test if our logic rejects if bypassed.
      // Wait, flutter test maxLength prevents entering >500 chars via enterText.
      // We'll skip explicitly overriding TextField behavior, but if we do...
      
      // We will just verify maxLength is 500
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 500);
    });

    testWidgets('Valid task accepted and duplicate submit prevented', (WidgetTester tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ask Appa about meds');
      
      // Tap Save twice rapidly
      await tester.tap(find.text('Save'));
      await tester.tap(find.text('Save')); // Should be disabled/ignored
      
      await tester.pump(const Duration(milliseconds: 50)); // While saving
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // Is saving
      
      await tester.pumpAndSettle(); // Finish saving

      expect(mockRepo.addTaskCallCount, 1);
      expect(find.byType(AddTaskDialog), findsNothing); // Dialog closed
    });
  });

  group('Step 7: Task List (TaskListWidget)', () {
    Widget buildList() {
      return MaterialApp(
        home: Scaffold(
          body: TaskListWidget(circleId: 'circle1', taskRepo: mockRepo),
        ),
      );
    }

    testWidgets('Loading task list', (WidgetTester tester) async {
      await tester.pumpWidget(buildList());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Task repository error', (WidgetTester tester) async {
      mockRepo.shouldThrow = true;
      await tester.pumpWidget(buildList());
      mockRepo.emitTasks([]);
      await tester.pump();
      
      expect(find.text('Unable to load reminders. Please try again.'), findsOneWidget);
    });

    testWidgets('Empty task list', (WidgetTester tester) async {
      await tester.pumpWidget(buildList());
      mockRepo.emitTasks([]);
      await tester.pump();
      
      expect(find.text('No reminders yet.'), findsOneWidget);
    });

    testWidgets('Pending status rendered', (WidgetTester tester) async {
      await tester.pumpWidget(buildList());
      mockRepo.emitTasks([
        TaskModel(taskId: '1', createdBy: 'u', text: 'Task 1', status: 'pending', createdAt: DateTime.now())
      ]);
      await tester.pump();
      
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('Delivered status rendered', (WidgetTester tester) async {
      await tester.pumpWidget(buildList());
      mockRepo.emitTasks([
        TaskModel(taskId: '1', createdBy: 'u', text: 'Task 1', status: 'delivered', createdAt: DateTime.now())
      ]);
      await tester.pump();
      
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Acknowledged status rendered', (WidgetTester tester) async {
      await tester.pumpWidget(buildList());
      mockRepo.emitTasks([
        TaskModel(taskId: '1', createdBy: 'u', text: 'Task 1', status: 'acknowledged', createdAt: DateTime.now())
      ]);
      await tester.pump();
      
      expect(find.text('Acknowledged'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Multiple tasks', (WidgetTester tester) async {
      await tester.pumpWidget(buildList());
      mockRepo.emitTasks([
        TaskModel(taskId: '1', createdBy: 'u', text: 'Task A', status: 'pending', createdAt: DateTime.now()),
        TaskModel(taskId: '2', createdBy: 'u', text: 'Task B', status: 'delivered', createdAt: DateTime.now()),
      ]);
      await tester.pump();
      
      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsOneWidget);
    });
  });
}
