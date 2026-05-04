// =============================================================================
// FILE: lib/services/session_timeout_service.dart
// REQ-2.17.7: Automatic session expiry after inactivity for the Client Portal
//             mobile application.
//
// Usage: Wrap the authenticated Scaffold body with SessionActivityWrapper.
// The widget resets the inactivity timer on any tap/touch.
// After [idleTimeout] of no activity, a warning dialog is shown.
// After [warnDuration] the user is automatically logged out.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../presentation/screens/auth/login_screen.dart';

/// Duration of inactivity before showing the warning dialog.
const Duration _idleTimeout = Duration(minutes: 15);

/// Duration of the warning countdown before auto-logout.
const Duration _warnDuration = Duration(minutes: 2);

/// Wraps any widget subtree and tracks user touch activity.
/// When [_idleTimeout] elapses without activity, shows a logout warning.
class SessionActivityWrapper extends StatefulWidget {
  final Widget child;

  const SessionActivityWrapper({super.key, required this.child});

  @override
  State<SessionActivityWrapper> createState() => _SessionActivityWrapperState();
}

class _SessionActivityWrapperState extends State<SessionActivityWrapper> {
  Timer? _idleTimer;
  Timer? _countdownTimer;
  int _secondsLeft = _warnDuration.inSeconds;
  bool _warningShown = false;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    _countdownTimer?.cancel();

    // Dismiss warning if it was shown
    if (_warningShown && mounted) {
      Navigator.of(context, rootNavigator: true).popUntil(
        (route) =>
            route.isFirst ||
            !route.settings.name.toString().contains('session_warn'),
      );
    }
    _warningShown = false;
    _secondsLeft = _warnDuration.inSeconds;

    _idleTimer = Timer(_idleTimeout, _onIdle);
  }

  void _onIdle() {
    if (!mounted || _warningShown) return;
    _warningShown = true;
    _secondsLeft = _warnDuration.inSeconds;
    _showWarningDialog();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        t.cancel();
        _logout();
      }
    });
  }

  void _logout() {
    // Pop the warning dialog if still open
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
    Navigator.of(context, rootNavigator: true).pop();
    _warningShown = false;
    _resetTimer();
  }

  void _showWarningDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      routeSettings: const RouteSettings(name: 'session_warn'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          // Sync countdown state into dialog via stream listen pattern
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.timer_outlined,
                      color: Color(0xFFD97706), size: 22),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
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
                        color: Color(0xFFEA580C)),
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
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Stay Signed In',
                      style: TextStyle(fontWeight: FontWeight.w600)),
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
