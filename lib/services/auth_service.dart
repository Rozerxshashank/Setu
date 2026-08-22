import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthService {
  // FIREBASE (Backup & Demo)
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  
  // SUPABASE (Primary)
  final sb.GoTrueClient _supabaseAuth = sb.Supabase.instance.client.auth;

  Stream<sb.AuthState> get authStateChanges => _supabaseAuth.onAuthStateChange;
  
  String? get currentUserId {
    if (_supabaseAuth.currentUser != null) {
      return _supabaseAuth.currentUser!.id;
    }
    return _firebaseAuth.currentUser?.uid;
  }

  Future<sb.AuthResponse> signUp(String email, String password, String name) async {
    return await _supabaseAuth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  Future<sb.AuthResponse> signIn(String email, String password) async {
    return await _supabaseAuth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabaseAuth.signOut();
    await _firebaseAuth.signOut();
  }

  // Preserve Firebase methods for Demo / Backup
  Future<void> signInAnonymously() async {
    try {
      await _firebaseAuth.signInAnonymously();
    } catch (_) {
      // Demo Mode fallback: allow local testing without Firebase config
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(fb_auth.FirebaseAuthException e) verificationFailed,
    required Function(fb_auth.PhoneAuthCredential credential) verificationCompleted,
    required Function(String verificationId) codeAutoRetrievalTimeout,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<fb_auth.UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = fb_auth.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _firebaseAuth.signInWithCredential(credential);
  }
}
