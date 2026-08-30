import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/profile_setup_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/create_family_circle_screen.dart';
import 'presentation/screens/invite_member_screen.dart';
import 'presentation/screens/family_circle_summary_screen.dart';
import 'presentation/screens/elder_view_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://test.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'test_anon_key'),
  );

  runApp(const SetuApp());
}

class SetuApp extends StatelessWidget {
  const SetuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Setu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/home': (context) => const HomeScreen(),
        '/create_circle': (context) => const CreateFamilyCircleScreen(),
        '/invite_member': (context) => const InviteMemberScreen(),
        '/circle_summary': (context) => const FamilyCircleSummaryScreen(),
        '/elder_view': (context) => const ElderViewScreen(),
      },
    );
  }
}
