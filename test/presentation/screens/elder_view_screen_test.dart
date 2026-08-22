import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu/presentation/screens/elder_view_screen.dart';
import 'package:setu/repositories/task_repository.dart';
import 'package:setu/models/task_model.dart';

class MockTaskRepositoryForElderView implements TaskRepository {
  @override
  Future<void> addTask(String circleId, TaskModel task) async {}

  @override
  Future<List<TaskModel>> getTasks(String circleId) async {
    return [];
  }

  @override
  Stream<List<TaskModel>> watchTasks(String circleId) {
    return Stream.value([]);
  }
}

void main() {
  testWidgets('ElderViewScreen renders UI correctly', (tester) async {
    final mockRepo = MockTaskRepositoryForElderView();

    await tester.pumpWidget(
      MaterialApp(
        home: ElderViewScreen(taskRepo: mockRepo),
      ),
    );

    // Verify main instruction
    expect(find.text('Good morning Amma. How are you feeling today?'), findsOneWidget);
    
    // Start Recording button should be visible
    expect(find.text('Start Recording'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);
  });

  testWidgets('ElderViewScreen renders recording instruction semantics', (tester) async {
    final mockRepo = MockTaskRepositoryForElderView();

    await tester.pumpWidget(
      MaterialApp(
        home: ElderViewScreen(taskRepo: mockRepo),
      ),
    );

    expect(
      find.text('Please send a voice message telling your family how you are doing.'),
      findsOneWidget,
    );
  });
}
