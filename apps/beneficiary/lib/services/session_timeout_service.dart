// =============================================================================
// FILE: apps/beneficiary/lib/services/session_timeout_service.dart
// REQ-2.17.7: Automatic session expiry after inactivity for the Beneficiary
//             Mobile Application.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../screens/app_lock_screen.dart';
import '../screens/login_screen.dart';

/// Duration of inactivity before showing the warning dialog.
const Duration _idleTimeout = Duration(minutes: 15);

/// Duration of the warning countdown before auto-logout.
const Duration _warnDuration = Duration(minutes: 2);

/// Inactivity before the protected-screen lock appears (F-08). The session
/// stays alive; the user unlocks with PIN or biometrics.
const Duration _lockTimeout = Duration(minutes: 5);

class SessionActivityWrapper extends StatefulWidget {
  final Widget child;

  const SessionActivityWrapper({super.key, required this.child});

  @override
  State<SessionActivityWrapper> createState() => _SessionActivityWrapperState();
}

class _SessionActivityWrapperState extends State<SessionActivityWrapper>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  Timer? _countdownTimer;
  Timer? _lockTimer;
  int _secondsLeft = _warnDuration.inSeconds;
  bool _warningShown = false;
  bool _lockShown = false;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _countdownTimer?.cancel();
    _lockTimer?.cancel();
    super.dispose();
  }

  // Dart timers may pause while the app is backgrounded, so compare against
  // wall-clock time of the last activity when the app returns to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (!ApiService.isLoggedIn) return;
    final idleFor = DateTime.now().difference(_lastActivity);
    if (idleFor >= _lockTimeout) _onLockIdle();
    if (idleFor >= _idleTimeout) _onIdle();
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    _countdownTimer?.cancel();
    _lockTimer?.cancel();
    _lastActivity = DateTime.now();

    if (_warningShown && mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
    _warningShown = false;
    _secondsLeft = _warnDuration.inSeconds;
    _idleTimer = Timer(_idleTimeout, _onIdle);
    _lockTimer = Timer(_lockTimeout, _onLockIdle);
  }

  void _onIdle() {
    if (!mounted || _warningShown) return;
    _warningShown = true;
    _secondsLeft = _warnDuration.inSeconds;
    _showWarningDialog();
  }

  void _onLockIdle() {
    if (!mounted || _lockShown || !ApiService.isLoggedIn) return;
    _showLock();
  }

  // Opaque route on the root navigator so the lock covers pushed screens too.
  // Touches on the lock screen are outside this wrapper, so they don't reset
  // the idle timers.
  void _showLock() {
    _lockShown = true;
    _lockTimer?.cancel();
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => AppLockScreen(
          onUnlocked: _unlock,
          onSignInAgain: _logout,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _unlock() {
    if (!mounted) return;
    if (_lockShown && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    _lockShown = false;
    _resetTimer();
  }

  void _logout() {
    _countdownTimer?.cancel();
    _lockTimer?.cancel();
    _lockShown = false;
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    ApiService.clearToken();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  void _stayLoggedIn() {
    _countdownTimer?.cancel();
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    _warningShown = false;
    _resetTimer();
  }

  void _showWarningDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          _countdownTimer?.cancel();
          _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (!mounted) {
              t.cancel();
              return;
            }
            setState(() => _secondsLeft--);
            setDialogState(() {});
            if (_secondsLeft <= 0) {
              t.cancel();
              _logout();
            }
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Session Expiring',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You will be automatically signed out due to inactivity.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Text(
                    '${_secondsLeft}s',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _stayLoggedIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF002E6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Stay Signed In',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _logout,
                  child: const Text(
                    'Sign Out Now',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
