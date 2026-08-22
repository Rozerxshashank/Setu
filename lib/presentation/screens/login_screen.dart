import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isOtpSent = false;
  String? _verificationId;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (often works on Android)
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/profile_setup');
            }
          } catch (e) {
            _showError('Verification failed. Please try again.');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _showError('Phone verification failed. Please check your number and network connection.');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isOtpSent = true;
              _isLoading = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      _showError('Unable to send OTP. Please try again later.');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.verifyOtp(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/profile_setup');
      }
    } catch (e) {
      _showError('Invalid or expired OTP. Please try again.');
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
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/profile_setup');
      }
    } catch (e) {
      _showError('Demo Login failed. Please try again.');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isOtpSent ? 'Enter OTP' : 'Enter your phone number',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!_isOtpSent)
              Semantics(
                label: 'Phone number input field',
                child: TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixText: '+91 ',
                  ),
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 18),
                ),
              )
            else
              Semantics(
                label: 'OTP input field',
                child: TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: '6-digit OTP',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
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
                    onPressed: _isOtpSent ? _verifyOtp : _sendOtp,
                    child: Text(
                      _isOtpSent ? 'Verify OTP' : 'Send OTP',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
            const SizedBox(height: 48),
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
