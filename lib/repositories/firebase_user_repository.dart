import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'user_repository.dart';

class FirebaseUserRepository implements UserRepository {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel?> getUser(String userId) async {
    final db = _firestore;
    if (db == null) return null;
    final doc = await db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data()!);
  }

  @override
  Stream<UserModel?> watchUser(String userId) {
    final db = _firestore;
    if (db == null) return Stream.value(null);
    return db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromJson(doc.data()!) : null);
  }

  @override
  Future<void> createUser(UserModel user) async {
    final db = _firestore;
    if (db == null) return;
    await db.collection('users').doc(user.userId).set(user.toJson());
  }

  @override
  Future<void> updateUser(UserModel user) async {
    final db = _firestore;
    if (db == null) return;
    await db.collection('users').doc(user.userId).update(user.toJson());
  }
}
