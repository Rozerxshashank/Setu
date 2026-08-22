import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  FirebaseMessaging? get _messaging {
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    try {
      final messaging = _messaging;
      if (messaging == null) return;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await _registerToken(token);
        }

        messaging.onTokenRefresh.listen((newToken) {
          _registerToken(newToken);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            print('Message received in foreground: ${message.notification?.title}');
          }
        });

        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          print('Message clicked!');
        });
      }
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    try {
      final user = _auth?.currentUser;
      final db = _firestore;
      if (user != null && db != null) {
        final userRef = db.collection('users').doc(user.uid);
        await userRef.set({
          'fcmTokens': FieldValue.arrayUnion([token])
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> removeToken() async {
    try {
      final user = _auth?.currentUser;
      final messaging = _messaging;
      final db = _firestore;
      if (user != null && messaging != null && db != null) {
        String? token = await messaging.getToken();
        if (token != null) {
          final userRef = db.collection('users').doc(user.uid);
          await userRef.update({
            'fcmTokens': FieldValue.arrayRemove([token])
          });
        }
      }
    } catch (_) {}
  }
}
