import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'user_repository.dart';

class SupabaseUserRepository implements UserRepository {
  final SupabaseClient _supabase;

  SupabaseUserRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  @override
  Future<UserModel?> getUser(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('id, name, phone_number')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return null;

      final memberships = await _supabase
          .from('circle_members')
          .select('circle_id')
          .eq('user_id', userId);

      final circleIds = (memberships as List)
          .map((m) => m['circle_id'] as String)
          .toList();

      return UserModel(
        userId: profile['id'] as String,
        name: profile['name'] as String? ?? 'Unknown',
        phoneNumber: profile['phone_number'] as String? ?? '',
        circleIds: circleIds,
        fcmTokens: [], // FCM tokens managed via fcm_tokens table
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<UserModel?> watchUser(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .asyncMap((data) async {
          if (data.isEmpty) return null;
          return await getUser(userId);
        });
  }

  @override
  Future<void> createUser(UserModel user) async {
    await _supabase.from('profiles').upsert({
      'id': user.userId,
      'name': user.name,
      'phone_number': user.phoneNumber,
    });
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await _supabase.from('profiles').update({
      'name': user.name,
      'phone_number': user.phoneNumber,
    }).eq('id', user.userId);
  }
}
