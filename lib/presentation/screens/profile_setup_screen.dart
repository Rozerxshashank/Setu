import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available from Supabase Auth metadata
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.userMetadata?['name'] != null) {
        _nameController.text = user.userMetadata!['name'] as String;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.person_outline, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'What should we call you?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This name will be visible to your Family Circle.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'Your Name Input',
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (_nameController.text.trim().isEmpty) return;
                      final navigator = Navigator.of(context);

                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        final supabaseUser = Supabase.instance.client.auth.currentUser;
                        if (supabaseUser != null) {
                          await Supabase.instance.client.from('profiles').upsert({
                            'id': supabaseUser.id,
                            'name': _nameController.text.trim(),
                            'phone_number': supabaseUser.phone ?? 'Unknown',
                          });
                        }
                      } catch (_) {
                        // Demo mode fallback: continue gracefully without blocking user
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                          navigator.pushReplacementNamed('/home');
                        }
                      }
                    },
                    child: Semantics(
                      button: true,
                      label: 'Complete Setup',
                      child: const Text(
                        'Complete Setup',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
