import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthService {
  final sb.GoTrueClient _supabaseAuth = sb.Supabase.instance.client.auth;

  Stream<sb.AuthState> get authStateChanges => _supabaseAuth.onAuthStateChange;
  
  String? get currentUserId {
    return _supabaseAuth.currentUser?.id;
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
  }

  Future<void> signInAnonymously() async {
    // Supabase does support anonymous sign-ins if enabled in the dashboard.
    await _supabaseAuth.signInAnonymously();
  }
}
