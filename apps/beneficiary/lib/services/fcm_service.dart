// lib/services/fcm_service.dart
// Firebase Cloud Messaging integration for the iDetect Beneficiary app.
//
// Responsibilities:
//   - Request notification permission on Android 13+
//   - Get the FCM token and register it with the API
//   - Handle foreground and background messages
//   - Refresh token when FCM rotates it
//
// Setup required (one-time, before building):
//   1. Go to https://console.firebase.google.com
//   2. Create a project (or use existing one)
//   3. Add Android app with package name: com.idetect.idetect_beneficiary
//   4. Download google-services.json → place in apps/beneficiary/android/app/
//   5. In the API, set FIREBASE_KEY_PATH in .env to your service account JSON

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

// ── Background message handler ─────────────────────────────────────────────
// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialized in background isolate too
  await Firebase.initializeApp();
  debugPrint(
    '🔔 [FCM-BG] ${message.notification?.title}: ${message.notification?.body}',
  );
  // The notification is already shown by the system.
  // Add local DB saving here if needed.
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Stream that HomeScreen listens to for foreground notifications
  static final _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get foregroundMessages =>
      _foregroundController.stream;

  /// Initialize FCM. Call this from main() after Firebase.initializeApp().
  static Future<void> initialize() async {
    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+ and iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('🔔 FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('🔔 FCM: User denied notifications');
      return;
    }

    // Get the token and send it to the API
    await _registerToken();

    // Re-register whenever FCM rotates the token
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔔 FCM token refreshed');
      if (ApiService.isLoggedIn) {
        await ApiService.registerDeviceToken(newToken);
      }
    });

    // Handle notifications that open the app from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Handle notifications that open the app from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Handle foreground notifications
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '🔔 [FCM-FG] ${message.notification?.title}: ${message.notification?.body}',
      );
      // Push to stream so HomeScreen can show a banner
      _foregroundController.add(message);
    });
  }

  /// Get the FCM token and register it with the API (if logged in).
  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('🔔 FCM: No token available');
        return;
      }
      debugPrint('🔔 FCM token: ${token.substring(0, 20)}...');
      if (ApiService.isLoggedIn) {
        await ApiService.registerDeviceToken(token);
      }
    } catch (e) {
      debugPrint('🔔 FCM token error: $e');
    }
  }

  /// Call this after login to ensure the token is registered.
  static Future<void> onLogin() async {
    await _registerToken();
  }

  /// Handle a notification tap (app opened via notification).
  static void _handleMessage(RemoteMessage message) {
    final type = message.data['type'] ?? '';
    debugPrint('🔔 FCM tapped: type=$type data=${message.data}');
    // Navigation on tap can be wired here via a GlobalKey<NavigatorState>
    // or a notification stream. For now just log the intent.
  }
}
