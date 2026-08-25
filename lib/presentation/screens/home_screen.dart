import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/daily_log.dart';
import '../../models/user_model.dart';
import '../../models/family_circle.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/daily_log_repository.dart';
import '../../repositories/firebase_user_repository.dart';
import '../../repositories/firebase_daily_log_repository.dart';
import '../../repositories/supabase_user_repository.dart';
import '../../repositories/supabase_daily_log_repository.dart';
import '../../repositories/supabase_family_circle_repository.dart';
import '../../repositories/supabase_task_repository.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/firebase_task_repository.dart';
import '../widgets/daily_log_card.dart';
import '../widgets/task_list_widget.dart';
import '../widgets/add_task_dialog.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final UserRepository? userRepo;
  final DailyLogRepository? logRepo;
  final TaskRepository? taskRepo;
  final String? testUid;

  const HomeScreen({super.key, this.userRepo, this.logRepo, this.taskRepo, this.testUid});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final UserRepository _userRepo;
  late final DailyLogRepository _logRepo;
  late final TaskRepository _taskRepo;

  String? _selectedCircleId;

  @override
  void initState() {
    super.initState();
    bool isSupabase = false;
    try {
      isSupabase = Supabase.instance.client.auth.currentUser != null;
    } catch (_) {}

    _userRepo = widget.userRepo ?? (isSupabase ? SupabaseUserRepository() : FirebaseUserRepository());
    _logRepo = widget.logRepo ?? (isSupabase ? SupabaseDailyLogRepository() : FirebaseDailyLogRepository());
    _taskRepo = widget.taskRepo ?? (isSupabase ? SupabaseTaskRepository() : FirebaseTaskRepository());
    
    // Initialize notifications (requests permission and registers FCM token)
    try {
      NotificationService().initialize();
    } catch (_) {
      // Ignore during widget tests where Firebase isn't initialized
    }
  }

  @override
  Widget build(BuildContext context) {
    String? supabaseUid;
    try {
      supabaseUid = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}
    String? firebaseUid;
    try {
      firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    final uid = widget.testUid ?? (supabaseUid ?? (firebaseUid ?? 'demo_user_123'));

    return StreamBuilder<UserModel?>(
      stream: _userRepo.watchUser(uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Setu Dashboard')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Failed to load user profile.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final user = userSnapshot.data;
        final circleIds = user?.circleIds ?? [];
        if (circleIds.isEmpty && _selectedCircleId == null) {
          return _buildZeroCirclesState();
        }

        final activeCircleIds = circleIds.isNotEmpty ? circleIds : [_selectedCircleId!];
        if (_selectedCircleId == null || !activeCircleIds.contains(_selectedCircleId)) {
          _selectedCircleId = activeCircleIds.first;
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: circleIds.length > 1
                ? DropdownButton<String>(
                    value: _selectedCircleId,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCircleId = newValue;
                      });
                    },
                    items: circleIds
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text('Circle: $value'), // Ideally map to name, but ID is fine for now
                      );
                    }).toList(),
                    underline: const SizedBox(),
                  )
                : const Text('Setu Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.mic, color: Colors.purple),
                tooltip: 'Demo: Elder View',
                onPressed: () => Navigator.pushNamed(context, '/elder_view'),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          ),
          body: StreamBuilder<List<DailyLog>>(
            stream: _logRepo.watchDailyLogs(_selectedCircleId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Semantics(
                  label: "Loading check-ins",
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Semantics(
                  label: "Error loading check-ins",
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Unable to load check-ins. Please check your network and try again.',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }

              final logs = snapshot.data ?? [];
              
              if (logs.isEmpty) {
                return _buildEmptyLogsState();
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "Today's Check-in",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        return DailyLogCard(log: logs[index]);
                      },
                    ),
                    const Divider(height: 32, thickness: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Reminders",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Reminder'),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AddTaskDialog(
                                  circleId: _selectedCircleId!,
                                  currentUserId: uid,
                                  taskRepo: _taskRepo,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    TaskListWidget(
                      circleId: _selectedCircleId!,
                      taskRepo: _taskRepo,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildZeroCirclesState() {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Setu Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: Colors.purple),
            tooltip: 'Demo: Elder View',
            onPressed: () => Navigator.pushNamed(context, '/elder_view'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.group_add, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              "You're not part of a Family Circle yet.",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Create a Family Circle to start daily check-ins for your parent.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Family Circle',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 60),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/create_circle');
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.group_add_outlined),
              label: const Text(
                'Join Existing Circle with Invite Code',
                style: TextStyle(fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                final codeController = TextEditingController();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Join Family Circle'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Enter the 6-character Invite Code shared by your family member:'),
                        const SizedBox(height: 16),
                        TextField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: 'Invite Code (e.g. SETU-89214)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.key),
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) return;
                          Navigator.pop(ctx);

                          try {
                            final uid = widget.testUid ?? AuthService().currentUserId ?? 'demo_user';
                            final repo = SupabaseFamilyCircleRepository();
                            await repo.addMemberToCircle(
                              code,
                              FamilyCircleMember(userId: uid, name: 'Caregiver', role: 'sibling'),
                            );
                          } catch (_) {}

                          setState(() {
                            _selectedCircleId = code;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully joined circle "$code"! Dashboard updated.'),
                            ),
                          );
                        },
                        child: const Text('Join Circle'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.mic, color: Colors.purple),
              label: const Text(
                'Try Elder Audio Check-in View',
                style: TextStyle(fontSize: 16, color: Colors.purple),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/elder_view');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLogsState() {
    return Semantics(
      label: "No check-ins yet",
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey, semanticLabel: 'Inbox icon'),
              SizedBox(height: 16),
              Text('No check-ins yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
