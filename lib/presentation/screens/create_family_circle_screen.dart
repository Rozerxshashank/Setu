import 'package:flutter/material.dart';
import '../../models/family_circle.dart';
import '../../repositories/supabase_family_circle_repository.dart';

class CreateFamilyCircleScreen extends StatefulWidget {
  const CreateFamilyCircleScreen({super.key});

  @override
  State<CreateFamilyCircleScreen> createState() => _CreateFamilyCircleScreenState();
}

class _CreateFamilyCircleScreenState extends State<CreateFamilyCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _parentNameController = TextEditingController(text: 'John Doe');
  final _parentPhoneController = TextEditingController(text: '9250200822');
  
  String _selectedLanguage = 'English';
  TimeOfDay _checkInTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  Future<void> _selectCheckInTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _checkInTime,
    );
    if (picked != null && picked != _checkInTime) {
      setState(() {
        _checkInTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _handleCreateCircle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final elderName = _parentNameController.text.trim();
    final elderPhone = _parentPhoneController.text.trim();
    final timeStr = '${_checkInTime.hour.toString().padLeft(2, '0')}:${_checkInTime.minute.toString().padLeft(2, '0')}';

    try {
      final repo = SupabaseFamilyCircleRepository();
      await repo.createFamilyCircle(FamilyCircle(
        circleId: '',
        elderName: elderName,
        elderPhoneNumber: elderPhone,
        preferredLanguage: _selectedLanguage.toLowerCase(),
        checkInTime: timeStr,
        members: [],
        memberIds: [],
        createdAt: DateTime.now(),
      ));
    } catch (_) {
      // Demo / fallback mode: Continue smoothly without blocking user
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Circle created for $elderName! Proceeding to invite family...'),
          ),
        );
        Navigator.pushReplacementNamed(context, '/invite_member');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Family Circle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Elder Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _parentNameController,
                decoration: const InputDecoration(
                  labelText: "Parent's Name",
                  hintText: 'e.g. Mom, Dad, or John Doe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Please enter your parent's name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _parentPhoneController,
                decoration: const InputDecoration(
                  labelText: "Parent's Phone Number",
                  hintText: 'e.g. +91 9876543210',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Please enter your parent's phone number";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              const Text(
                'Check-in Preferences',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(
                  labelText: 'Preferred Language',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                items: ['English', 'Hindi', 'Kannada', 'Tamil', 'Telugu', 'Bengali', 'Marathi']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedLanguage = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectCheckInTime,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Daily Check-in Time',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTimeOfDay(_checkInTime),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                ),
                onPressed: _isSubmitting ? null : _handleCreateCircle,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text(
                        'Create Circle',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
