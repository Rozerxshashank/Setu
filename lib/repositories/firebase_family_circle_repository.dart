import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/family_circle.dart';
import 'family_circle_repository.dart';

class FirebaseFamilyCircleRepository implements FamilyCircleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  Future<FamilyCircle?> getFamilyCircle(String circleId) async {
    final doc = await _firestore
        .collection('familyCircles')
        .doc(circleId)
        .get();
    if (!doc.exists) return null;
    return FamilyCircle.fromJson(doc.data()!);
  }

  @override
  Future<void> createFamilyCircle(FamilyCircle circle) async {
    // Client-side creates are blocked. We call the Cloud Function.
    final callable = _functions.httpsCallable('createCircle');
    await callable.call({
      'elderName': circle.elderName,
      'elderPhoneNumber': circle.elderPhoneNumber,
      'preferredLanguage': circle.preferredLanguage,
      'checkInTime': circle.checkInTime,
      'interactionChannel': circle.interactionChannel,
    });
  }

  @override
  Future<void> addMemberToCircle(
    String circleId,
    FamilyCircleMember member,
  ) async {
    // In production, we don't arbitrarily add members. We redeem an invite.
    // For this implementation, we map this to joinCircle assuming 'circleId' holds an invite token.
    final callable = _functions.httpsCallable('joinCircle');
    await callable.call({'inviteId': circleId});
  }
}
