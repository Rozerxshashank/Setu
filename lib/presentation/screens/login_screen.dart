import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  final AuthService? authService;
  const LoginScreen({super.key, this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // For Signup

  bool _isLoading = false;
  bool _isSignupMode = false;

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password.');
      return;
    }
    
    if (_isSignupMode && name.isEmpty) {
      _showError('Please enter your name for signup.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignupMode) {
        await _authService.signUp(email, password, name);
        // Supabase might require email confirmation, but assuming auto-confirm for now
      } else {
        await _authService.signIn(email, password);
      }
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/profile_setup');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('YOUR_SUPABASE_URL') || errStr.contains('placeholder') || errStr.contains('Failed host lookup')) {
        _showError('Invalid Supabase URL. Pass your real Supabase URL via --dart-define=SUPABASE_URL=...');
      } else {
        _showError('Unable to connect. Check your internet connection & Supabase configuration.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _demoLogin() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _authService.signInAnonymously();
    } catch (_) {}
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/profile_setup');
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignupMode ? 'Create Account' : 'Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isSignupMode ? 'Sign up for Setu' : 'Welcome back to Setu',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isSignupMode)
              Semantics(
                label: 'Name input field',
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            if (_isSignupMode) const SizedBox(height: 16),
            Semantics(
              label: 'Email input field',
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Password input field',
              child: TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    onPressed: _submitAuth,
                    child: Text(
                      _isSignupMode ? 'Sign Up' : 'Login',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSignupMode = !_isSignupMode;
                });
              },
              child: Text(
                _isSignupMode 
                  ? 'Already have an account? Login' 
                  : 'Don\'t have an account? Sign Up',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'If Firebase Phone Authentication is not configured in your environment, use Demo Authentication for development testing.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: "Demo mode login",
              child: TextButton.icon(
                onPressed: _demoLogin,
                icon: const Icon(Icons.science, color: Colors.blue),
                label: const Text(
                  '[Demo Mode] Continue without OTP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
