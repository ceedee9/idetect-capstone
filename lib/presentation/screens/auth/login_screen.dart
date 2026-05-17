import 'package:flutter/material.dart';
import '../../../core/constants/app_design_system.dart';
import '../../../services/api_service.dart';
import '../home/home_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // If a valid token was restored from storage on app startup,
    // skip the login form and go straight to HomeScreen.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundDarkBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/idetect_logo.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 6),
                const Text(
                  'ESTABLISHMENT PORTAL',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 48),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.backgroundWhite,
                    borderRadius: AppDesignSystem.cardRadius,
                    boxShadow: AppDesignSystem.shadowLG,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: AppDesignSystem.inputRadius,
                            border: Border.all(
                              color: AppDesignSystem.statusInvalid.withOpacity(0.4),
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

                      // Email field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppDesignSystem.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(
                            color: AppDesignSystem.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: 'you@example.com',
                          hintStyle: const TextStyle(
                            color: AppDesignSystem.textTertiary,
                          ),
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: AppDesignSystem.iconLight,
                            size: 22,
                          ),
                          filled: true,
                          fillColor: AppDesignSystem.backgroundLightBlue,
                          border: OutlineInputBorder(
                            borderRadius: AppDesignSystem.inputRadius,
                            borderSide: const BorderSide(color: AppDesignSystem.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppDesignSystem.inputRadius,
                            borderSide: const BorderSide(color: AppDesignSystem.borderLight, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppDesignSystem.inputRadius,
                            borderSide: const BorderSide(color: AppDesignSystem.secondaryBlue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppDesignSystem.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(
                            color: AppDesignSystem.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: 'Your password',
                          hintStyle: const TextStyle(
                            color: AppDesignSystem.textTertiary,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppDesignSystem.iconLight,
                            size: 22,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppDesignSystem.iconLight,
                              size: 22,
                            ),
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                          filled: true,
                          fillColor: AppDesignSystem.backgroundLightBlue,
                          border: OutlineInputBorder(
                            borderRadius: AppDesignSystem.inputRadius,
                            borderSide: const BorderSide(color: AppDesignSystem.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppDesignSystem.inputRadius,
                            borderSide: const BorderSide(color: AppDesignSystem.borderLight, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppDesignSystem.inputRadius,
                            borderSide: const BorderSide(color: AppDesignSystem.secondaryBlue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                        onSubmitted: (_) => _login(),
                      ),

                      const SizedBox(height: 28),

                      // Sign In button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppDesignSystem.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: AppDesignSystem.primaryBlue.withOpacity(0.4),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppDesignSystem.buttonRadius,
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
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
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
    );
  }
}
