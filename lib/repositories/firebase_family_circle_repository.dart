import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/family_circle.dart';
import 'family_circle_repository.dart';

class FirebaseFamilyCircleRepository implements FamilyCircleRepository {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFunctions? get _functions {
    try {
      return FirebaseFunctions.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FamilyCircle?> getFamilyCircle(String circleId) async {
    final db = _firestore;
    if (db == null) return null;
    final doc = await db
        .collection('familyCircles')
        .doc(circleId)
        .get();
    if (!doc.exists) return null;
    return FamilyCircle.fromJson(doc.data()!);
  }

  @override
  Future<void> createFamilyCircle(FamilyCircle circle) async {
    final fn = _functions;
    if (fn == null) return;
    final callable = fn.httpsCallable('createCircle');
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
    final fn = _functions;
    if (fn == null) return;
    final callable = fn.httpsCallable('joinCircle');
    await callable.call({'inviteId': circleId});
  }
}
