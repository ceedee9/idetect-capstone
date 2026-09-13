import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import 'login_screen.dart';

enum AppNoticeType { success, error, info }

class AppNotice extends StatelessWidget {
  const AppNotice({super.key, required this.type, required this.message});

  final AppNoticeType type;
  final String message;

  static const _styles = {
    AppNoticeType.success: (
      accent: Color(0xFF15803D),
      bg: Color(0xFFF0FDF4),
      icon: Icons.check_circle_outline_rounded,
      label: 'Success',
    ),
    AppNoticeType.error: (
      accent: Color(0xFFDC2626),
      bg: Color(0xFFFFF1F2),
      icon: Icons.error_outline_rounded,
      label: 'Error',
    ),
    AppNoticeType.info: (
      accent: Color(0xFF00225F),
      bg: Color(0xFFEEF2FA),
      icon: Icons.info_outline_rounded,
      label: 'Notice',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final s = _styles[type]!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: s.bg,
        border: Border(left: BorderSide(color: s.accent, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, size: 18, color: s.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label.toUpperCase(),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: s.accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF334155), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const _institutional = Color(0xFF00225F);
  static const _fieldFill = Color(0xFFF6F8FB);
  static const _fieldBorder = Color(0xFFE3E7EE);

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _errorMessage;
  bool _success = false;
  // True only when the backend told us the session/token itself is gone
  // (401), as opposed to an ordinary wrong-current-password error. Drives
  // the info-styled notice + redirect-to-login branch in _submit() below,
  // instead of the normal error banner.
  bool _redirectingToLogin = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      return 'Please fill in all three fields.';
    }
    if (next.length < 8) {
      return 'New password must be at least 8 characters.';
    }
    if (next != confirm) {
      return 'New password and confirmation do not match.';
    }
    if (next == current) {
      return 'New password must be different from your current password.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
        _success = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await ApiService.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _loading = false;
        _success = true;
        _errorMessage = null;
      });
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();

      // Give the person a moment to see the success notice, then
      // return to the profile drawer.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
      return;
    }

    if (result.sessionExpired) {
      // ApiService.changePassword already cleared the stale token.
      // Show a brief notice, then drop the whole nav stack and send
      // the establishment back to LoginScreen — same pattern as the
      // profile drawer's own _logout().
      setState(() {
        _loading = false;
        _success = false;
        _redirectingToLogin = true;
        _errorMessage = result.errorMessage;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    setState(() {
      _loading = false;
      _success = false;
      _errorMessage =
          result.errorMessage ?? 'Could not update password. Please try again.';
    });
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexMono(
        color: const Color(0xFF94A3B8),
        fontSize: 10,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !obscure,
      style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            size: 20, color: Color(0xFF64748B)),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
            color: const Color(0xFF64748B),
          ),
          tooltip: obscure ? 'Hide password' : 'Show password',
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: _fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _fieldBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _institutional, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _institutional,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Change Password',
          style: GoogleFonts.sourceSerif4(
              fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose a new password for your establishment account.',
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              if (_success)
                const AppNotice(
                  type: AppNoticeType.success,
                  message: 'Password updated. Returning to your profile…',
                ),
              if (_redirectingToLogin)
                AppNotice(
                  type: AppNoticeType.info,
                  message:
                      '${_errorMessage ?? 'Your session has expired.'} Redirecting to login…',
                ),
              if (_errorMessage != null && !_redirectingToLogin && !_success)
                AppNotice(type: AppNoticeType.error, message: _errorMessage!),
              _fieldLabel('Current Password'),
              const SizedBox(height: 6),
              _passwordField(
                controller: _currentController,
                hintText: 'Enter current password',
                obscure: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
              ),
              const SizedBox(height: 16),
              _fieldLabel('New Password'),
              const SizedBox(height: 6),
              _passwordField(
                controller: _newController,
                hintText: 'At least 8 characters',
                obscure: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Confirm New Password'),
              const SizedBox(height: 6),
              _passwordField(
                controller: _confirmController,
                hintText: 'Re-enter new password',
                obscure: _showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _institutional,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Update Password',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
