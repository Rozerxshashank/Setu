import '../models/family_circle.dart';

abstract class FamilyCircleRepository {
  Future<FamilyCircle?> getFamilyCircle(String circleId);
  Future<void> createFamilyCircle(FamilyCircle circle);
  Future<void> addMemberToCircle(String circleId, FamilyCircleMember member);
}

class MockFamilyCircleRepository implements FamilyCircleRepository {
  final Map<String, FamilyCircle> _circles = {};

  @override
  Future<FamilyCircle?> getFamilyCircle(String circleId) async {
    await Future.delayed(const Duration(seconds: 1));
    return _circles[circleId];
  }

  @override
  Future<void> createFamilyCircle(FamilyCircle circle) async {
    await Future.delayed(const Duration(seconds: 1));
    _circles[circle.circleId] = circle;
  }

  @override
  Future<void> addMemberToCircle(
    String circleId,
    FamilyCircleMember member,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_circles.containsKey(circleId)) {
      final circle = _circles[circleId]!;
      circle.members.add(member);
      if (!circle.memberIds.contains(member.userId)) {
        circle.memberIds.add(member.userId);
      }
      _circles[circleId] = circle; // Assuming mutable list
    }
  }
}
