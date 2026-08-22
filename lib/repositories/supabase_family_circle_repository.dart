import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family_circle.dart';
import 'family_circle_repository.dart';

class SupabaseFamilyCircleRepository implements FamilyCircleRepository {
  final SupabaseClient _supabase;

  SupabaseFamilyCircleRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  @override
  Future<FamilyCircle?> getFamilyCircle(String circleId) async {
    try {
      final circle = await _supabase
          .from('family_circles')
          .select('id, elder_name, elder_phone_number, preferred_language, check_in_time, timezone, interaction_channel, consent_granted, created_at')
          .eq('id', circleId)
          .maybeSingle();

      if (circle == null) return null;

      final membersData = await _supabase
          .from('circle_members')
          .select('user_id, name, role')
          .eq('circle_id', circleId);

      final members = (membersData as List).map((m) {
        return FamilyCircleMember(
          userId: m['user_id'] as String,
          name: m['name'] as String? ?? 'Unknown',
          role: m['role'] as String? ?? 'sibling',
        );
      }).toList();

      final memberIds = members.map((m) => m.userId).toList();

      DateTime createdAtDate = DateTime.now();
      if (circle['created_at'] != null) {
        createdAtDate = DateTime.tryParse(circle['created_at'] as String) ?? DateTime.now();
      }

      return FamilyCircle(
        circleId: circle['id'] as String,
        elderName: circle['elder_name'] as String,
        elderPhoneNumber: circle['elder_phone_number'] as String? ?? '',
        preferredLanguage: circle['preferred_language'] as String? ?? 'english',
        checkInTime: circle['check_in_time'] as String? ?? '09:00',
        timezone: circle['timezone'] as String? ?? 'Asia/Kolkata',
        interactionChannel: circle['interaction_channel'] as String? ?? 'whatsapp',
        members: members,
        memberIds: memberIds,
        createdAt: createdAtDate,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> createFamilyCircle(FamilyCircle circle) async {
    final res = await _supabase.functions.invoke('create-circle', body: {
      'elder_name': circle.elderName,
      'elder_phone_number': circle.elderPhoneNumber,
      'preferred_language': circle.preferredLanguage,
      'check_in_time': circle.checkInTime,
      'timezone': circle.timezone,
      'interaction_channel': circle.interactionChannel,
      'consent_granted': true,
    });

    if (res.status != 200 && res.status != 201) {
      throw Exception(res.data?['error'] ?? 'Failed to create circle');
    }
  }

  @override
  Future<void> addMemberToCircle(
    String circleId,
    FamilyCircleMember member,
  ) async {
    final res = await _supabase.functions.invoke('join-circle', body: {
      'invite_id': circleId,
    });

    if (res.status != 200 && res.status != 201) {
      throw Exception(res.data?['error'] ?? 'Failed to join circle');
    }
  }
}
