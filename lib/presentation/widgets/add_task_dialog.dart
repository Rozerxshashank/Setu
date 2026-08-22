import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../repositories/task_repository.dart';

class AddTaskDialog extends StatefulWidget {
  final String circleId;
  final String currentUserId;
  final TaskRepository taskRepo;

  const AddTaskDialog({
    super.key,
    required this.circleId,
    required this.currentUserId,
    required this.taskRepo,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _controller = TextEditingController();
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_isSaving) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Task text cannot be empty');
      return;
    }
    if (text.length > 500) {
      setState(() => _errorText = 'Task text cannot exceed 500 characters');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final task = TaskModel(
        taskId: 'task_${DateTime.now().millisecondsSinceEpoch}',
        createdBy: widget.currentUserId,
        text: text,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await widget.taskRepo.addTask(widget.circleId, task);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder added.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'Failed to add reminder. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Semantics(
        header: true,
        child: const Text('Add Reminder'),
      ),
      content: Semantics(
        label: 'Reminder text input',
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'e.g., "Did you take your blood pressure medication?"',
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),
          maxLength: 500,
          maxLines: 3,
          enabled: !_isSaving,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Semantics(
          button: true,
          label: _isSaving ? "Saving reminder" : "Save reminder",
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveTask,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
      ],
    );
  }
}
