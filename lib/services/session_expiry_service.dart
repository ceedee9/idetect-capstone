// =============================================================================
// FILE: lib/services/session_expiry_service.dart
// Signs the user out and returns to the login screen when the session ends,
// instead of leaving them on a screen where every action fails.
//
// Triggers:
//   - the server rejects the token (see session_http.dart), or
//   - the app resumes or regains connectivity holding an expired token.
//
// An expired token alone never signs the user out while the server is
// unreachable: offline scans keep working and queue as usual. The sign-in is
// required once the phone is back online.
// =============================================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../presentation/screens/auth/login_screen.dart';
import 'api_service.dart';
import 'session_http.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class SessionExpiryService with WidgetsBindingObserver {
  SessionExpiryService._();

  static final SessionExpiryService _instance = SessionExpiryService._();
  static StreamSubscription<ConnectivityResult>? _connectivitySub;
  static bool _checking = false;

  static void init() {
    sessionEndedHook = _onServerRejectedToken;
    WidgetsBinding.instance.addObserver(_instance);
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) checkExpiredSession();
    });
  }

  /// Signs out and shows the login screen if the stored token has expired and
  /// the server can be reached.
  static Future<void> checkExpiredSession() async {
    if (await clearExpiredSessionIfOnline()) _showLogin();
  }

  /// Clears an expired token when the server is reachable, without any
  /// navigation (the splash screen picks the login screen itself). Returns
  /// true if the session was cleared.
  static Future<bool> clearExpiredSessionIfOnline() async {
    if (_checking || !ApiService.hasExpiredToken) return false;
    _checking = true;
    try {
      final expiredToken = ApiService.token;
      if (!await ApiService.isServerReachable()) return false;
      // The user may have signed in again while we were checking.
      if (ApiService.token != expiredToken) return false;
      ApiService.markSessionExpired();
      ApiService.clearToken();
      return true;
    } finally {
      _checking = false;
    }
  }

  static void _onServerRejectedToken(String? requestToken) {
    // A late response for an older token must not sign out a newer login,
    // and once signed out, other in-flight requests are ignored.
    if (requestToken != ApiService.token) return;
    ApiService.markSessionExpired();
    ApiService.clearToken();
    _showLogin();
  }

  static void _showLogin() {
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkExpiredSession();
  }
}
