import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu/presentation/screens/login_screen.dart';
import 'package:setu/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class MockAuthServiceForTest implements AuthService {
  bool isLoginMode = true;
  bool throwError = false;
  String errorMsg = '';
  
  @override
  String? get currentUserId => null;

  @override
  Stream<sb.AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<sb.AuthResponse> signIn(String email, String password) async {
    if (throwError) {
      throw sb.AuthException(errorMsg);
    }
    return sb.AuthResponse(user: null, session: null);
  }

  @override
  Future<void> signInAnonymously() async {
    if (throwError) {
      throw Exception('Demo Login failed');
    }
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<sb.AuthResponse> signUp(String email, String password, String name) async {
    if (throwError) {
      throw sb.AuthException(errorMsg);
    }
    return sb.AuthResponse(user: null, session: null);
  }

  @override
  Future<fb_auth.UserCredential> verifyOtp({required String verificationId, required String smsCode}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> verifyPhoneNumber({required String phoneNumber, required Function(String verificationId, int? resendToken) codeSent, required Function(fb_auth.FirebaseAuthException e) verificationFailed, required Function(fb_auth.PhoneAuthCredential credential) verificationCompleted, required Function(String verificationId) codeAutoRetrievalTimeout}) async {
    throw UnimplementedError();
  }
}

void main() {
  group('LoginScreen Tests (Supabase Auth)', () {
    late MockAuthServiceForTest mockAuthService;

    setUp(() {
      mockAuthService = MockAuthServiceForTest();
    });

    Widget createLoginScreen() {
      return MaterialApp(
        home: LoginScreen(authService: mockAuthService),
        routes: {
          '/profile_setup': (context) => const Scaffold(body: Text('Profile Setup')),
        },
      );
    }

    testWidgets('renders email login mode initially', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      
      expect(find.text('Welcome back to Setu'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.text('Login'), findsWidgets); // Appbar and button
      expect(find.text('Don\'t have an account? Sign Up'), findsOneWidget);
      expect(find.textContaining('[Demo Mode]'), findsOneWidget);
    });

    testWidgets('switches to signup mode and renders name field', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      
      await tester.tap(find.text('Don\'t have an account? Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Sign up for Setu'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Full Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.text('Already have an account? Login'), findsOneWidget);
    });

    testWidgets('shows validation error for empty fields in login', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      
      expect(find.text('Please enter email and password.'), findsOneWidget);
    });

    testWidgets('shows validation error for missing name in signup', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      
      await tester.tap(find.text('Don\'t have an account? Sign Up'));
      await tester.pumpAndSettle();
      
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();
      
      expect(find.text('Please enter your name for signup.'), findsOneWidget);
    });

    testWidgets('handles Supabase login error', (tester) async {
      mockAuthService.throwError = true;
      mockAuthService.errorMsg = 'Invalid login credentials';
      
      await tester.pumpWidget(createLoginScreen());
      
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong_pass');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      
      expect(find.text('Invalid email or password. Please try again.'), findsOneWidget);
    });

    testWidgets('handles demo mode login', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      
      await tester.tap(find.textContaining('[Demo Mode]'));
      await tester.pumpAndSettle();
      
      expect(find.text('Demo Login failed. Please try again.'), findsNothing);
    });
  });
}
