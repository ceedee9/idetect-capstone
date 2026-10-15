// =============================================================================
// FILE: apps/beneficiary/lib/screens/app_lock_screen.dart
// F-08: Protected-screen lock shown after ~5 minutes of inactivity.
//       Unlocks with PIN (server-verified) or biometrics. "Sign in again"
//       is the fallback for devices without either, and it does a full logout.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

// Keys must match login_screen.dart.
const _kSavedId = 'saved_id_number';
const _kBiometricEnabled = 'biometric_enabled';
const _kPinSet = 'pin_set';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onSignInAgain;

  const AppLockScreen({
    super.key,
    required this.onUnlocked,
    required this.onSignInAgain,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _loaded = false;
  bool _pinSet = false;
  bool _biometricEnabled = false;
  bool _verifying = false;
  String _pin = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pinSet = prefs.getBool(_kPinSet) ?? false;
      _biometricEnabled = prefs.getBool(_kBiometricEnabled) ?? false;
      _loaded = true;
    });
    if (_biometricEnabled) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: loc.lockBiometricReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      // Cancelled or unavailable: PIN or "sign in again" still work.
    }
  }

  void _onDigit(String digit) {
    if (_verifying || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) _submitPin();
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submitPin() async {
    final loc = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final idNumber =
        prefs.getString(_kSavedId) ??
        (ApiService.currentUser?['id_number'] as String?);
    if (!mounted) return;
    if (idNumber == null) {
      setState(() {
        _pin = '';
        _error = loc.lockSessionMissing;
      });
      return;
    }

    setState(() => _verifying = true);
    final result = await ApiService.loginWithPin(idNumber: idNumber, pin: _pin);
    if (!mounted) return;
    if (result.success) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _verifying = false;
      _pin = '';
      _error = result.errorMessage ?? loc.lockIncorrectPin;
    });
  }

  Widget _pinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _pin.length ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        );
      }),
    );
  }

  Widget _keypad(AppLocalizations loc) {
    Widget padKey(Widget child, VoidCallback? onTap) {
      return SizedBox(
        width: 72,
        height: 72,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            foregroundColor: Colors.white,
          ),
          child: child,
        ),
      );
    }

    Widget digit(String d) => padKey(
      Text(
        d,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      ),
      () => _onDigit(d),
    );

    Widget row(List<Widget> children) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );

    return Column(
      children: [
        row([digit('1'), digit('2'), digit('3')]),
        const SizedBox(height: 12),
        row([digit('4'), digit('5'), digit('6')]),
        const SizedBox(height: 12),
        row([digit('7'), digit('8'), digit('9')]),
        const SizedBox(height: 12),
        row([
          _biometricEnabled
              ? Tooltip(
                  message: loc.lockBiometricButton,
                  child: padKey(
                    const Icon(Icons.fingerprint, size: 30),
                    _tryBiometric,
                  ),
                )
              : const SizedBox(width: 72, height: 72),
          digit('0'),
          padKey(const Icon(Icons.backspace_outlined), _onBackspace),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF002E6B),
        body: SafeArea(
          child: !_loaded
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          color: Colors.white,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.lockTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.lockSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFBFDBFE),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_pinSet) ...[
                          Text(
                            loc.lockEnterPin,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _pinDots(),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 20,
                            child: _verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : _error != null
                                ? Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 13,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _keypad(loc),
                        ] else if (_biometricEnabled)
                          ElevatedButton.icon(
                            onPressed: _tryBiometric,
                            icon: const Icon(Icons.fingerprint),
                            label: Text(loc.lockBiometricButton),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF002E6B),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          )
                        else
                          Text(
                            loc.lockNoUnlockMethod,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFBFDBFE),
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: widget.onSignInAgain,
                          child: Text(
                            loc.lockSignInAgain,
                            style: const TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
