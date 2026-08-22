import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    // Request permission (Caregiver side)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get the initial token
      String? token = await _messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        _registerToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          print('Message received in foreground: ${message.notification?.title}');
          // Note: In a full production app, you might show a local notification or snackbar here.
        }
      });

      // Handle taps when the app is in the background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Message clicked!');
        // Tapping automatically brings the user to the app. 
        // We could use a GlobalKey<NavigatorState> to route to /home if needed, 
        // but the caregiver will naturally open to the dashboard.
      });
    }
  }

  Future<void> _registerToken(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      final userRef = _firestore.collection('users').doc(user.uid);
      
      // Use arrayUnion to safely add the token without overwriting other tokens
      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token])
      }, SetOptions(merge: true));
    }
  }

  Future<void> removeToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      String? token = await _messaging.getToken();
      if (token != null) {
        final userRef = _firestore.collection('users').doc(user.uid);
        await userRef.update({
          'fcmTokens': FieldValue.arrayRemove([token])
        });
      }
    }
  }
}
