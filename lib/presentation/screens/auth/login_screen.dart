// NOTE: this screen now depends on google_fonts, which the project does
// not currently have installed. Before this compiles, run:
//   flutter pub add google_fonts
//
// Font choices deliberately mirror the web admin portals' type system so
// the establishment app reads as the same product family:
//   - display/headline: Source Serif 4 (web's serif token)
//   - small-caps labels / mono accents: IBM Plex Mono (web's mono token)
// If/when AppDesignSystem gets a font-token section of its own, these
// GoogleFonts calls should move there so every screen shares one source
// of truth instead of each screen importing google_fonts individually.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_design_system.dart';
import '../../../services/api_service.dart';
import '../home/home_screen.dart';

/// Shared by the splash and the login header so the logo glides between them.
const kBrandLogoHeroTag = 'brand-logo';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;

  // Flattened, registry-style tokens for this screen. These deviate
  // slightly from AppDesignSystem's existing cardRadius/inputRadius/
  // shadowLG (which read as fairly rounded + heavily elevated,
  // matching the "generic app template" look we moved away from on
  // web) — worth eventually promoting into AppDesignSystem proper if
  // other screens adopt the same flatter direction.
  static const _cardRadius = 14.0;
  static const _fieldRadius = 8.0;
  static const _fieldFill = Color(0xFFF6F8FB);
  static const _fieldBorder = Color(0xFFE3E7EE);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ApiService.isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result.errorMessage ?? 'Login failed. Please try again.';
      });
    }
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexMono(
        color: AppDesignSystem.textTertiary,
        fontSize: 10,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppDesignSystem.textTertiary),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _fieldBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(
          color: AppDesignSystem.secondaryBlue,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The login background is blue at the top, so status bar icons are light.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppDesignSystem.backgroundDarkBlue,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/LOG IN PAGE BG.jpg', fit: BoxFit.cover),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Gradient disc keeps the logo legible over the blue background.
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/Background_Graident.png',
                                fit: BoxFit.cover,
                              ),
                              Center(
                                child: Hero(
                                  tag: kBrandLogoHeroTag,
                                  child: Image.asset(
                                    'assets/images/Business_Establishment_Logo_noBG.png',
                                    width: 130,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'ESTABLISHMENT PORTAL',
                        style: GoogleFonts.ibmPlexMono(
                          color: Colors.white,
                          fontSize: 11,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Login Card — flattened: smaller radius, thin
                      // hairline border, lighter shadow than the
                      // previous shadowLG treatment.
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.backgroundWhite,
                          borderRadius: BorderRadius.circular(_cardRadius),
                          border: Border.all(color: _fieldBorder, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign In',
                              style: GoogleFonts.sourceSerif4(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Use your establishment credentials',
                              style: AppDesignSystem.bodySmall,
                            ),

                            const SizedBox(height: 24),

                            // Error message
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius:
                                      BorderRadius.circular(_fieldRadius),
                                  border: Border.all(
                                    color: AppDesignSystem.statusInvalid
                                        .withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AppDesignSystem.statusInvalid,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: AppDesignSystem.statusInvalid,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Email field — label sits above the field
                            // (mono, small-caps) instead of Material's
                            // floating inline label, matching the web
                            // ID-data-field pattern.
                            _fieldLabel('Email'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppDesignSystem.textPrimary,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'you@example.com',
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: AppDesignSystem.iconLight,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Password field
                            _fieldLabel('Password'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppDesignSystem.textPrimary,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'Your password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppDesignSystem.iconLight,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppDesignSystem.iconLight,
                                    size: 20,
                                  ),
                                  tooltip: _showPassword
                                      ? 'Hide password'
                                      : 'Show password',
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                ),
                              ),
                              onSubmitted: (_) => _login(),
                            ),

                            const SizedBox(height: 28),

                            // Sign In button — flattened elevation to
                            // match the flatter web button treatment.
                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppDesignSystem.primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(_fieldRadius),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Sign In',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.0,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
