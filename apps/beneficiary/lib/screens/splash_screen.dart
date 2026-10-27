import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Opening screen: animated brand reveal, then routes to Home or Login.
/// Tap anywhere to skip. Respects the OS "remove animations" setting.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _totalDuration = Duration(milliseconds: 3000);
  static const _holdDuration = Duration(milliseconds: 400);
  static const _logoAsset = 'assets/images/Beneficiary_Logo_noBG.png';
  static const _backgroundAsset = 'assets/images/LANDING PAGE BG.jpg';

  late final AnimationController _controller;
  late final Animation<double> _logoIn;
  late final Animation<double> _sheen;
  late final Animation<double> _taglineIn;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);
    _logoIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    );
    _sheen = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.8, curve: Curves.easeInOut),
    );
    _taglineIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(_holdDuration, _goNext);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
        Future.delayed(const Duration(milliseconds: 1000), _goNext);
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    // A remembered account always opens on the PIN screen.
    final remembered = await hasRememberedAccount();
    if (!mounted) return;
    final next = !remembered && ApiService.isLoggedIn
        ? const HomeScreen()
        : const LoginScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The gradient is white in the top-right corner, so the status bar
      // icons must be dark here. Each following screen sets its own style.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goNext,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(_backgroundAsset, fit: BoxFit.cover),
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 36),
                      FadeTransition(
                        opacity: _taglineIn,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(_taglineIn),
                          child: _buildTagline(loc.loginBeneficiaryPortal),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1.0).animate(_logoIn),
      child: FadeTransition(
        opacity: _logoIn,
        child: AnimatedBuilder(
          animation: _sheen,
          builder: (context, child) {
            // Light band sweeps across the logo once, then disappears.
            final percent = -1.5 + 3.0 * _sheen.value;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white.withAlpha(170),
                  Colors.transparent,
                ],
                stops: const [0.4, 0.5, 0.6],
                transform: _SheenTransform(percent),
              ).createShader(bounds),
              child: child,
            );
          },
          child: Hero(
            tag: kBrandLogoHeroTag,
            child: Image.asset(_logoAsset, width: 280),
          ),
        ),
      ),
    );
  }

  Widget _buildTagline(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: AppDesignSystem.heading4.copyWith(
          color: AppDesignSystem.primaryBlue,
        ),
      ),
    );
  }
}

class _SheenTransform extends GradientTransform {
  const _SheenTransform(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}
