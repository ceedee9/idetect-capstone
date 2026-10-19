import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import 'home_screen.dart';

/// Keys for remembering the beneficiary so they don't re-type next time.
const _kSavedId = 'saved_id_number';
const _kSavedBirthdate = 'saved_birthdate';
const _kSavedName = 'saved_full_name';
const _kBiometricEnabled = 'biometric_enabled';
const _kPinSet = 'pin_set';

/// True if an account was activated on this phone. Used by the splash to
/// send returning users to the PIN screen instead of straight into the app.
Future<bool> hasRememberedAccount() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kSavedId) != null;
}

/// Notice types for the shared _Notice widget below — replaces three
/// separately hand-styled boxes (mobile-registration explainer,
/// OTP-sent instruction, error banner) with one consistent component.
/// Icon + color + text always together, per this file's own WCAG 1.4.1
/// commitment (never color alone).
enum _NoticeType { info, success, error }

class _Notice extends StatelessWidget {
  const _Notice({required this.type, this.title, required this.message});

  final _NoticeType type;
  final String? title;
  final String message;

  static const _config = {
    _NoticeType.info: (
      color: AppDesignSystem.interactiveBlue,
      icon: Icons.info_outline,
    ),
    _NoticeType.success: (
      color: AppDesignSystem.statusValid,
      icon: Icons.check_circle,
    ),
    _NoticeType.error: (
      color: AppDesignSystem.statusInvalid,
      icon: Icons.error_outline,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = _config[type]!;
    return Semantics(
      liveRegion: type == _NoticeType.error,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.color.withAlpha(20),
          borderRadius: AppDesignSystem.cardRadius,
          border: Border.all(color: c.color.withAlpha(60)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(c.icon, color: c.color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppDesignSystem.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: c.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    style: AppDesignSystem.bodyMedium.copyWith(color: c.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Login phases:
///  welcome      = first screen: activate my account, or sign in
///  idEntry      = ID + birthdate form (or welcome-back if remembered)
///  registerMobile = first-time, no mobile on file
///  otpEntry     = OTP entry (large numpad)
///  pinEntry     = PIN entry for returning users
enum _Phase { welcome, idEntry, registerMobile, otpEntry, pinEntry }

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _mobileController = TextEditingController();
  final _localAuth = LocalAuthentication();

  _Phase _phase = _Phase.welcome;
  bool _loaded = false;
  bool _isActivating = true;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _selectedDate;

  // Remembered user
  String? _savedName;
  bool _hasSavedId = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  // OTP state
  String _otpDigits = '';

  // PIN state
  String _pinDigits = '';
  bool _hasPinSet = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _idController.dispose();
    _birthdateController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  // ── Saved credentials ──────────────────────────────────────────────────

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kSavedId);
    final bd = prefs.getString(_kSavedBirthdate);
    final name = prefs.getString(_kSavedName);
    final bioEnabled = prefs.getBool(_kBiometricEnabled) ?? false;
    final pinSet = prefs.getBool(_kPinSet) ?? false;

    if (id != null && bd != null) {
      _idController.text = id;
      _birthdateController.text = bd;
      _selectedDate = DateTime.tryParse(bd);
      _hasSavedId = true;
      _savedName = name;
      _biometricEnabled = bioEnabled;
      _hasPinSet = pinSet;
      _phase = pinSet ? _Phase.pinEntry : _Phase.idEntry;
    }

    // Check if device supports biometrics
    try {
      final canAuth =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      _biometricAvailable = canAuth;
    } catch (_) {
      _biometricAvailable = false;
    }

    if (mounted) setState(() => _loaded = true);

    // Auto-attempt biometric login if everything is set up
    if (_hasSavedId && _biometricEnabled && ApiService.isLoggedIn) {
      _attemptBiometric();
    }
  }

  Future<void> _saveCredentials(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedId, _idController.text.trim());
    await prefs.setString(_kSavedBirthdate, _birthdateController.text);
    await prefs.setString(_kSavedName, name);
  }

  Future<void> _clearSaved() async {
    // Also drops the session token and cached profile so the next person
    // starts clean.
    ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedId);
    await prefs.remove(_kSavedBirthdate);
    await prefs.remove(_kSavedName);
    await prefs.remove(_kBiometricEnabled);
    await prefs.remove(_kPinSet);
    setState(() {
      _hasSavedId = false;
      _savedName = null;
      _biometricEnabled = false;
      _hasPinSet = false;
      _idController.clear();
      _birthdateController.clear();
      _selectedDate = null;
      _phase = _Phase.welcome;
      _errorMessage = null;
    });
  }

  // ── Biometric ──────────────────────────────────────────────────────────

  Future<void> _attemptBiometric() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: loc.loginBiometricReasonSignIn,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (ok && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (_) {
      // biometric failed, fall through to manual login
    }
  }

  Future<void> _enableBiometric() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: loc.loginBiometricReasonEnable,
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kBiometricEnabled, true);
        setState(() => _biometricEnabled = true);
      }
    } catch (_) {}
  }

  // ── Date picker ──────────────────────────────────────────────────────

  Future<void> _pickBirthdate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1970, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppDesignSystem.primaryBlue,
            ),
            textTheme: Theme.of(
              context,
            ).textTheme.copyWith(headlineMedium: const TextStyle(fontSize: 28)),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _birthdateController.text =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // ── Request OTP ──────────────────────────────────────────────────────

  Future<void> _requestOtp() async {
    final loc = AppLocalizations.of(context)!;
    if (_idController.text.trim().isEmpty || _selectedDate == null) {
      setState(() => _errorMessage = loc.loginErrorMissingIdBirthdate);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.requestOtp(
      idNumber: _idController.text.trim(),
      birthdate: _birthdateController.text,
    );

    setState(() => _isLoading = false);

    if (result['error'] != null) {
      final days = result['suspension_days_remaining'];
      final suspensionMessage = result['suspension_status'] != null
          ? (days is num && days > 0
              ? '${result['error']} ${days.toInt()} day(s) remaining. End date: ${result['suspension_end_date']}.'
              : '${result['error']} The suspension period has ended and is awaiting office review.')
          : result['error'];
      setState(() => _errorMessage = suspensionMessage);
    } else if (result['mobile_required'] == true) {
      // No mobile on file — show registration form
      setState(() {
        _savedName = result['beneficiary_name'];
        _phase = _Phase.registerMobile;
        _errorMessage = null;
      });
    } else {
      // OTP sent successfully
      setState(() {
        _phase = _Phase.otpEntry;
        _otpDigits = '';
        _errorMessage = null;
      });
    }
  }

  // ── Register Mobile ──────────────────────────────────────────────────

  Future<void> _submitMobile() async {
    final loc = AppLocalizations.of(context)!;
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      setState(() => _errorMessage = loc.loginErrorMissingMobile);
      return;
    }

    // Basic PH mobile validation
    final mobileRegex = RegExp(r'^(\+?63|0)9\d{9}$');
    if (!mobileRegex.hasMatch(mobile)) {
      setState(() => _errorMessage = loc.loginErrorInvalidMobile);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.registerMobile(
      idNumber: _idController.text.trim(),
      birthdate: _birthdateController.text,
      mobileNumber: mobile,
    );

    setState(() => _isLoading = false);

    if (result['error'] != null) {
      setState(() => _errorMessage = result['error']);
    } else {
      // Mobile registered, OTP sent — go to OTP screen
      setState(() {
        _phase = _Phase.otpEntry;
        _otpDigits = '';
        _errorMessage = null;
      });
    }
  }

  // ── Verify OTP ──────────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    if (_otpDigits.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.verifyOtp(
      idNumber: _idController.text.trim(),
      otp: _otpDigits,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      // Register FCM token now that we have an auth token
      await FcmService.onLogin();

      // Remember credentials
      await _saveCredentials(result.fullName ?? '');

      if (!mounted) return;

      // Offer security setup (PIN first, then biometric)
      if (!_hasPinSet) {
        _showPinSetupPrompt();
      } else if (_biometricAvailable && !_biometricEnabled) {
        _showBiometricPrompt();
      } else {
        _goHome();
      }
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
        _otpDigits = '';
      });
    }
  }

  void _showPinSetupPrompt() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.cardRadius),
        title: Row(
          children: [
            Icon(Icons.pin, color: AppDesignSystem.primaryBlue, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.loginSetPinDialogTitle,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          loc.loginSetPinDialogContent,
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Still offer biometric if available
              if (_biometricAvailable && !_biometricEnabled) {
                _showBiometricPrompt();
              } else {
                _goHome();
              }
            },
            child: Text(loc.loginNotNow, style: const TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              // Show PIN entry phase for setup
              setState(() {
                _phase = _Phase.pinEntry;
                _pinDigits = '';
                _errorMessage = null;
              });
            },
            child: Text(
              loc.loginSetPinNow,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPinSetup() async {
    if (_pinDigits.length != 4) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.setPin(_pinDigits);

    setState(() => _isLoading = false);

    if (result['pin_set'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPinSet, true);
      _hasPinSet = true;

      if (!mounted) return;

      // Now offer biometric
      if (_biometricAvailable && !_biometricEnabled) {
        _showBiometricPrompt();
      } else {
        _goHome();
      }
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Failed to set PIN';
        _pinDigits = '';
      });
    }
  }

  Future<void> _loginWithPin() async {
    if (_pinDigits.length != 4) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.loginWithPin(
      idNumber: _idController.text.trim(),
      pin: _pinDigits,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      await FcmService.onLogin();
      await _saveCredentials(result.fullName ?? '');
      if (!mounted) return;
      _goHome();
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
        _pinDigits = '';
      });
    }
  }

  void _showBiometricPrompt() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.cardRadius),
        title: Row(
          children: [
            Icon(
              Icons.fingerprint,
              color: AppDesignSystem.primaryBlue,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.loginQuickSignInTitle,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          loc.loginQuickSignInContent,
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goHome();
            },
            child: Text(loc.loginNotNow, style: const TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _enableBiometric();
              _goHome();
            },
            child: Text(
              loc.loginYesEnable,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  // ── Numpad helpers ──────────────────────────────────────────────────
  // Haptic feedback on every tap — tactile confirmation matters more
  // for this audience than a purely visual response, especially for
  // anyone with reduced vision confirming a digit actually registered.

  void _onNumpadTap(String digit) {
    if (_otpDigits.length < 6) {
      HapticFeedback.lightImpact();
      setState(() => _otpDigits += digit);
      if (_otpDigits.length == 6) {
        _verifyOtp();
      }
    }
  }

  void _onNumpadDelete() {
    if (_otpDigits.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(
        () => _otpDigits = _otpDigits.substring(0, _otpDigits.length - 1),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/LOG IN PAGE BG.jpg', fit: BoxFit.cover),
          SafeArea(
            child: !_loaded
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        _buildHeader(loc),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.backgroundWhite,
                            borderRadius: AppDesignSystem.cardRadius,
                            boxShadow: AppDesignSystem.shadowMD,
                          ),
                          child: Column(
                            children: [
                              if (_phase == _Phase.welcome) _buildWelcome(),
                              if (_phase == _Phase.idEntry) _buildIdEntry(),
                              if (_phase == _Phase.registerMobile)
                                _buildMobileRegistration(),
                              if (_phase == _Phase.otpEntry) _buildOtpEntry(),
                              if (_phase == _Phase.pinEntry) _buildPinEntry(),

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                _Notice(
                                  type: _NoticeType.error,
                                  title: null,
                                  message: _errorMessage!,
                                ),
                              ],

                              // Dev-mode skip login
                              if (kDebugMode) ...[
                                const SizedBox(height: 32),
                                const Divider(),
                                TextButton.icon(
                                  onPressed: () {
                                    ApiService.setToken(
                                      'dev-skip-token',
                                      user: {
                                        'full_name': 'Dev User',
                                        'beneficiary_type': 'senior_citizen',
                                        'id_number': 'DEV-0001',
                                        'type': 'beneficiary',
                                      },
                                    );
                                    _goHome();
                                  },
                                  icon: const Icon(
                                    Icons.developer_mode,
                                    size: 20,
                                  ),
                                  label: const Text('Skip Login (Dev Mode)'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header (logo on the brand gradient) ───────────────────────────────

  Widget _buildHeader(AppLocalizations loc) {
    return Column(
      children: [
        // White disc keeps the logo readable over every band of the gradient
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppDesignSystem.backgroundWhite,
            shape: BoxShape.circle,
            boxShadow: AppDesignSystem.shadowMD,
          ),
          child: Image.asset(
            'assets/images/Beneficiary_Logo_noBG.png',
            width: 150,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          loc.loginBeneficiaryPortal,
          style: AppDesignSystem.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Phase: Welcome (activate vs sign in) ──────────────────────────────

  Widget _buildWelcome() {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          loc.loginWelcomeTitle,
          style: AppDesignSystem.heading2.copyWith(
            color: AppDesignSystem.primaryBlue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          loc.loginWelcomeSubtitle,
          style: AppDesignSystem.bodyLarge.copyWith(
            color: AppDesignSystem.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _buildWelcomeOption(
          icon: Icons.how_to_reg_outlined,
          label: loc.loginActivateButton,
          hint: loc.loginActivateHint,
          color: AppDesignSystem.primaryBlue,
          onTap: () => _openForm(activating: true),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => _openForm(activating: false),
          child: Text(
            loc.loginAlreadyHaveAccount,
            style: TextStyle(
              fontSize: 16,
              color: AppDesignSystem.interactiveBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeOption({
    required IconData icon,
    required String label,
    required String hint,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppDesignSystem.buttonRadius,
              ),
              elevation: 2,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            icon: Icon(icon, size: 26),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          style: AppDesignSystem.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _openForm({required bool activating}) {
    setState(() {
      _isActivating = activating;
      _phase = _Phase.idEntry;
      _errorMessage = null;
    });
  }

  // ── Phase 0: ID Entry ──────────────────────────────────────────────────

  Widget _buildIdEntry() {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Welcome-back greeting for returning users
        if (_hasSavedId && _savedName != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppDesignSystem.backgroundInput,
              borderRadius: AppDesignSystem.cardRadius,
            ),
            child: Column(
              children: [
                Icon(Icons.waving_hand, size: 36, color: Colors.amber.shade700),
                const SizedBox(height: 8),
                Text(
                  loc.loginWelcomeBack,
                  style: AppDesignSystem.bodyMedium.copyWith(
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _savedName!,
                  style: AppDesignSystem.heading4.copyWith(
                    fontSize: 22,
                    color: AppDesignSystem.primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Biometric button (big, prominent)
          if (_biometricAvailable && _biometricEnabled) ...[
            SizedBox(
              width: double.infinity,
              height: 72,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesignSystem.buttonRadius,
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _attemptBiometric();
                },
                icon: const Icon(
                  Icons.fingerprint,
                  size: 32,
                  color: Colors.white,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    loc.loginSignInFingerprint,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(loc.loginOrSignInOtp, style: AppDesignSystem.caption),
            const SizedBox(height: 12),
          ],

          // PIN login button for returning users
          if (_hasPinSet) ...[
            SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: AppDesignSystem.primaryBlue,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesignSystem.buttonRadius,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _phase = _Phase.pinEntry;
                    _pinDigits = '';
                    _errorMessage = null;
                  });
                },
                icon: const Icon(Icons.pin, size: 26),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    loc.loginSignInPin,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Quick OTP login — ID is pre-filled, just tap
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: AppDesignSystem.primaryBlue,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDesignSystem.buttonRadius,
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      _requestOtp();
                    },
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sms_outlined, size: 26),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  loc.loginSendOtp,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // "Not you?" link
          TextButton(
            onPressed: _clearSaved,
            child: Text(
              loc.loginNotYou,
              style: TextStyle(
                fontSize: 15,
                color: AppDesignSystem.interactiveBlue,
              ),
            ),
          ),
        ] else ...[
          // First-time user — activate or sign in with ID + birthdate
          Text(
            _isActivating ? loc.loginActivateTitle : loc.loginSignInButton,
            style: AppDesignSystem.heading4.copyWith(
              color: AppDesignSystem.primaryBlue,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isActivating) ...[
            const SizedBox(height: 8),
            Text(
              loc.loginActivateSubtitle,
              style: AppDesignSystem.bodyMedium.copyWith(
                color: AppDesignSystem.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),

          // ID Number
          TextField(
            controller: _idController,
            style: const TextStyle(fontSize: 20, letterSpacing: 1),
            decoration:
                AppDesignSystem.inputDecoration(
                  hintText: loc.loginIdNumberHint,
                  prefixIcon: Icons.badge_outlined,
                ).copyWith(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),

          // Birthdate
          Semantics(
            button: true,
            label: loc.loginBirthdateHint,
            child: TextField(
              controller: _birthdateController,
              readOnly: true,
              onTap: _pickBirthdate,
              style: const TextStyle(fontSize: 20),
              decoration:
                  AppDesignSystem.inputDecoration(
                    hintText: loc.loginBirthdateHint,
                    prefixIcon: Icons.calendar_today_outlined,
                  ).copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down, size: 30),
                  ),
            ),
          ),
          const SizedBox(height: 24),

          // Request OTP button — large
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              style: AppDesignSystem.primaryButton.copyWith(
                minimumSize: WidgetStateProperty.all(
                  const Size(double.infinity, 64),
                ),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _requestOtp();
                    },
              child: _isLoading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        loc.loginContinue,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _Notice(type: _NoticeType.info, message: loc.loginActivateHelp),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _phase = _Phase.welcome;
              _errorMessage = null;
            }),
            child: Text(
              loc.commonBack,
              style: TextStyle(fontSize: 16, color: AppDesignSystem.interactiveBlue),
            ),
          ),
        ],
      ],
    );
  }

  // ── Phase 1: Mobile Registration ──────────────────────────────────────

  Widget _buildMobileRegistration() {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        _Notice(
          type: _NoticeType.info,
          title: _savedName != null ? loc.loginHelloName(_savedName!) : null,
          message: loc.loginMobileExplanation,
        ),
        const SizedBox(height: 24),

        // Mobile input — large
        TextField(
          controller: _mobileController,
          style: const TextStyle(fontSize: 22, letterSpacing: 1.5),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            LengthLimitingTextInputFormatter(13),
          ],
          decoration:
              AppDesignSystem.inputDecoration(
                hintText: '09171234567',
                prefixIcon: Icons.phone_outlined,
              ).copyWith(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          // Was 14sp — below this file's own stated 15sp caption floor.
          loc.loginMobileHintFormat,
          style: AppDesignSystem.caption,
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: AppDesignSystem.buttonRadius,
              ),
            ),
            onPressed: _isLoading
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    _submitMobile();
                  },
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 24),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                loc.loginRegisterSendOtp,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => setState(() {
            _phase = _Phase.idEntry;
            _errorMessage = null;
          }),
          child: Text(
            loc.commonBack,
            style: TextStyle(
              fontSize: 16,
              color: AppDesignSystem.interactiveBlue,
            ),
          ),
        ),
      ],
    );
  }

  // ── Phase 2: OTP Entry (large numpad) ──────────────────────────────────

  Widget _buildOtpEntry() {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        _Notice(
          type: _NoticeType.success,
          title: null,
          message: loc.loginOtpSentInstruction,
        ),
        const SizedBox(height: 24),

        // OTP display boxes. Uses Expanded (not fixed widths) so the row
        // always fits the available width instead of hard-overflowing on
        // narrower screens — 6 fixed-48px boxes + 5x8px gaps summed to a
        // rigid 328px, which only fit on ~376px+ wide screens.
        Semantics(
          label: 'One-time code, ${_otpDigits.length} of 6 digits entered',
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filled = i < _otpDigits.length;
                      return Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: filled
                              ? AppDesignSystem.primaryBlue.withAlpha(25)
                              : AppDesignSystem.backgroundInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: filled
                                ? AppDesignSystem.primaryBlue
                                : AppDesignSystem.borderLight,
                            width: filled ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          filled ? _otpDigits[i] : '',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppDesignSystem.primaryBlue,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(
              color: AppDesignSystem.primaryBlue,
            ),
          ),

        const SizedBox(height: 16),

        // Large numpad
        _buildNumpad(),

        const SizedBox(height: 16),

        // Back / resend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _phase = _Phase.idEntry;
                _otpDigits = '';
                _errorMessage = null;
              }),
              child: Text(
                loc.commonBack,
                style: TextStyle(
                  fontSize: 16,
                  color: AppDesignSystem.interactiveBlue,
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _requestOtp,
              child: Text(
                loc.loginResendOtp,
                style: TextStyle(
                  fontSize: 16,
                  color: AppDesignSystem.interactiveBlue,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Phase 3: PIN Entry (setup or login) ──────────────────────────────

  /// True if user has a valid auth token (meaning they just OTP'd and are setting up)
  bool get _isPinSetup => ApiService.isLoggedIn && !_hasPinSet;

  Widget _buildPinEntry() {
    final loc = AppLocalizations.of(context)!;
    final isSetup = _isPinSetup;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppDesignSystem.primaryBlue.withAlpha(15),
            borderRadius: AppDesignSystem.cardRadius,
          ),
          child: Column(
            children: [
              Icon(
                isSetup ? Icons.pin : Icons.lock_outline,
                size: 40,
                color: AppDesignSystem.primaryBlue,
              ),
              const SizedBox(height: 8),
              Text(
                isSetup ? loc.loginCreatePin : loc.loginEnterPin,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppDesignSystem.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSetup ? loc.loginPinSetupHint : loc.loginPinLoginHint,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppDesignSystem.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // PIN display (4 dots/circles)
        Semantics(
          label: 'PIN, ${_pinDigits.length} of 4 digits entered',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pinDigits.length;
              return Container(
                width: 56,
                height: 56,
                margin: EdgeInsets.only(left: i > 0 ? 16 : 0),
                decoration: BoxDecoration(
                  color: filled
                      ? AppDesignSystem.primaryBlue
                      : AppDesignSystem.backgroundInput,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: filled
                        ? AppDesignSystem.primaryBlue
                        : AppDesignSystem.borderLight,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: filled
                    ? const Icon(Icons.circle, size: 18, color: Colors.white)
                    : null,
              );
            }),
          ),
        ),

        if (_isLoading) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: AppDesignSystem.primaryBlue),
        ],

        const SizedBox(height: 20),

        // Reuse large numpad but for PIN
        _buildNumpad(forPin: true),

        const SizedBox(height: 16),

        if (isSetup)
          TextButton(
            onPressed: () => setState(() {
              _phase = _Phase.idEntry;
              _pinDigits = '';
              _errorMessage = null;
            }),
            child: Text(
              loc.commonBack,
              style: TextStyle(
                fontSize: 16,
                color: AppDesignSystem.interactiveBlue,
              ),
            ),
          )
        else ...[
          if (_biometricAvailable && _biometricEnabled)
            TextButton.icon(
              onPressed: _isLoading ? null : () => _attemptBiometric(),
              icon: const Icon(Icons.fingerprint, size: 26),
              label: Text(
                loc.loginSignInFingerprint,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          TextButton(
            onPressed: _isLoading ? null : _requestOtp,
            child: Text(
              loc.loginForgotPin,
              style: TextStyle(
                fontSize: 16,
                color: AppDesignSystem.interactiveBlue,
              ),
            ),
          ),
          TextButton(
            onPressed: _clearSaved,
            child: Text(
              loc.loginSwitchAccount,
              style: TextStyle(
                fontSize: 16,
                color: AppDesignSystem.interactiveBlue,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Numpad ──────────────────────────────────────────────────────────────

  void _onPinTap(String digit) {
    if (_pinDigits.length < 4) {
      HapticFeedback.lightImpact();
      setState(() => _pinDigits += digit);
      if (_pinDigits.length == 4) {
        if (_isPinSetup) {
          _submitPinSetup();
        } else {
          _loginWithPin();
        }
      }
    }
  }

  void _onPinDelete() {
    if (_pinDigits.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(
        () => _pinDigits = _pinDigits.substring(0, _pinDigits.length - 1),
      );
    }
  }

  Widget _buildNumpad({bool forPin = false}) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 88, height: 64);
              }
              final isDel = key == 'DEL';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 88,
                  height: 64,
                  child: Semantics(
                    label: isDel ? 'Delete last digit' : 'Digit $key',
                    button: true,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDel
                            ? AppDesignSystem.backgroundWarm
                            : Colors.white,
                        foregroundColor: isDel
                            ? AppDesignSystem.accentRed
                            : AppDesignSystem.primaryBlue,
                        elevation: isDel ? 0 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDel
                                ? AppDesignSystem.borderLight
                                : AppDesignSystem.primaryBlue.withAlpha(50),
                          ),
                        ),
                      ),
                      onPressed: isDel
                          ? (forPin ? _onPinDelete : _onNumpadDelete)
                          : () => forPin ? _onPinTap(key) : _onNumpadTap(key),
                      child: isDel
                          ? const Icon(Icons.backspace_outlined, size: 26)
                          : Text(
                              key,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
