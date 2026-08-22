import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../repositories/task_repository.dart';

class TaskListWidget extends StatelessWidget {
  final String circleId;
  final TaskRepository taskRepo;

  const TaskListWidget({
    super.key,
    required this.circleId,
    required this.taskRepo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: taskRepo.watchTasks(circleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Semantics(
              label: "Error loading reminders",
              child: const Text(
                'Unable to load reminders. Please try again.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No reminders yet.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Semantics(
              label: 'Reminder: ${task.text}. Status: ${task.status}.',
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                child: ListTile(
                  title: Text(task.text),
                  subtitle: _buildStatus(task),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatus(TaskModel task) {
    IconData icon;
    Color color;
    String label;

    switch (task.status) {
      case 'delivered':
        icon = Icons.send;
        color = Colors.blue;
        label = 'Delivered';
        break;
      case 'acknowledged':
        icon = Icons.check_circle;
        color = Colors.green;
        label = 'Acknowledged';
        break;
      case 'pending':
      default:
        icon = Icons.access_time;
        color = Colors.orange;
        label = 'Pending';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color, semanticLabel: '$label icon'),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          if (task.deliveredInCheckInDate != null) ...[
            const SizedBox(width: 8),
            Text(
              '(${task.deliveredInCheckInDate})',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]
        ],
      ),
    );
  }
}
