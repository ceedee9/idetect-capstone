// =============================================================================
// FILE: lib/core/constants/app_design_system.dart
// PURPOSE: iDetect Establishment Design System
//
// Design Direction: "Raw & Authentic" â€” Professional tool aesthetic
// Used by: Establishment staff (cashiers, security, managers)
// Design Goals:
//   â€¢ Immediate visual clarity for scan results (Valid / Invalid / Suspicious)
//   â€¢ Task-focused â€” every interaction leads to an outcome
//   â€¢ High contrast â€” legible in varied lighting (indoor/outdoor)
//   â€¢ Bold, workmanlike typography â€” no decoration for its own sake
//   â€¢ Gestalt grouping â€” clear visual hierarchy through proximity & contrast
// =============================================================================

import 'package:flutter/material.dart';

class AppDesignSystem {
  AppDesignSystem._();

  // ===========================================================================
  // BRAND COLORS
  // ===========================================================================

  /// Deep navy â€” trust, authority, government
  static const Color primaryBlue = Color(0xFF002E6B);

  /// Accent red â€” from iDetect logo "DETECT" text
  static const Color accentRed = Color(0xFFE94444);

  /// Interactive blue â€” links, active states (higher saturation for clarity)
  static const Color secondaryBlue = Color(0xFF1A56DB);

  // ===========================================================================
  // STATUS COLORS â€” Maximum contrast for instant recognition (WCAG AA+)
  // Always paired with icon + text label (never color alone)
  // ===========================================================================

  /// VALID â€” High-saturation green visible in any lighting condition
  static const Color statusValid = Color(0xFF0D8A00);

  /// INVALID â€” Alert red; not to be confused with brand red (different hue)
  static const Color statusInvalid = Color(0xFFCC0000);

  /// SUSPICIOUS â€” Deep amber; between valid and invalid
  static const Color statusSuspicious = Color(0xFFB85B00);

  /// MANUAL REVIEW â€” Slate blue; neutral, "needs attention"
  static const Color statusManualReview = Color(0xFF1A56DB);

  /// FLAGGED â€” Crimson; most serious status
  static const Color statusFlagged = Color(0xFF9B1C1C);

  // ===========================================================================
  // BACKGROUNDS
  // ===========================================================================

  /// Main screen background â€” slightly warm to reduce eye fatigue
  static const Color backgroundLight = Color(0xFFF5F6F8);

  /// Card / surface white â€” sits on backgroundLight
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  /// Dark â€” overlays, scan viewport borders
  static const Color backgroundDark = Color(0xFF1A1D23);

  /// Deep blue â€” headers, hero sections
  static const Color backgroundDarkBlue = Color(0xFF002E6B);

  /// Input fill â€” crisp, clean field background
  static const Color backgroundLightBlue = Color(0xFFEEF3FD);

  // ===========================================================================
  // TEXT COLORS â€” All WCAG AA compliant on their respective backgrounds
  // ===========================================================================

  /// Primary â€” near-black for maximum legibility
  static const Color textPrimary = Color(0xFF0E1117);

  /// Secondary â€” medium gray (5.2:1 on white) âœ… AA
  static const Color textSecondary = Color(0xFF545E6B);

  /// Tertiary / placeholder (use at 16sp+ to meet AA for large text)
  static const Color textTertiary = Color(0xFF8C98A4);

  /// On dark backgrounds
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// On primary blue
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ===========================================================================
  // UI ELEMENTS
  // ===========================================================================

  static const Color borderLight = Color(0xFFDDE1E7);
  static const Color borderMedium = Color(0xFFB0B7C0);
  static const Color divider = Color(0xFFECEFF1);
  static const Color iconDark = Color(0xFF2C3E50);
  static const Color iconLight = Color(0xFF6B7A8D);

  // ===========================================================================
  // TYPOGRAPHY â€” Bold, direct, workmanlike
  //
  // Scale notes:
  //   â€¢ Body sizes are 1pt larger than Figma to improve scanning legibility
  //   â€¢ Headings are heavier (w800) for faster visual parsing
  //   â€¢ Status text is oversized deliberately â€” it IS the critical info
  // ===========================================================================

  static const String fontFamily = 'Roboto';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  /// Screen titles â€” on dark backgrounds, wide tracking for impact
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: textOnDark,
    letterSpacing: 1.2,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textOnDark,
    letterSpacing: 0.2,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: textOnPrimary,
    letterSpacing: 0.3,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textOnPrimary,
    letterSpacing: 0.2,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.3,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle instruction = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: textOnDark,
    height: 1.5,
  );

  /// Status text â€” deliberately large; it IS the most important information
  static const TextStyle statusText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  // ===========================================================================
  // SPACING â€” 8dp base grid
  // ===========================================================================

  static const double spaceUnit = 8.0;
  static const double spaceXXS = 4.0;
  static const double spaceXS = 8.0;
  static const double spaceSM = 16.0;
  static const double spaceMD = 24.0;
  static const double spaceLG = 32.0;
  static const double spaceXL = 40.0;
  static const double spaceXXL = 48.0;

  static const double screenPaddingHorizontal = 20.0;
  static const double screenPaddingVertical = 16.0;
  static const double cardPadding = 16.0;
  static const double cardSpacing = 12.0;
  static const double buttonPadding = 16.0;
  static const double inputPadding = 16.0;
  static const double sectionSpacing = 32.0;

  // ===========================================================================
  // BORDER RADIUS â€” Slightly less rounded = more "professional tool" feel
  // ===========================================================================

  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(radiusSM));
  static const BorderRadius inputRadius =
      BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius bottomSheetRadius =
      BorderRadius.vertical(top: Radius.circular(radiusXL));

  // ===========================================================================
  // SHADOWS â€” Stronger depth cues; tactile, physical feel
  // ===========================================================================

  static List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withOpacity(0.14),
      blurRadius: 12,
      offset: const Offset(0, 5),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Colors.black.withOpacity(0.20),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // ===========================================================================
  // BUTTON STYLES
  // ===========================================================================

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: textOnPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
    elevation: 3,
    shadowColor: primaryBlue.withOpacity(0.4),
    textStyle: buttonMedium,
    minimumSize: const Size(double.infinity, 56),
  );

  static ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: primaryBlue,
    side: const BorderSide(color: primaryBlue, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
    textStyle: buttonMedium.copyWith(color: primaryBlue),
    minimumSize: const Size(double.infinity, 56),
  );

  static ButtonStyle textButton = TextButton.styleFrom(
    foregroundColor: secondaryBlue,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    textStyle:
        bodyMedium.copyWith(fontWeight: FontWeight.w600, color: secondaryBlue),
  );

  // ===========================================================================
  // INPUT DECORATION
  // ===========================================================================

  static InputDecoration inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: bodyMedium.copyWith(color: textTertiary),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: iconLight, size: 22)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: backgroundLightBlue,
      border: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: borderLight, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: secondaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: statusInvalid, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: statusInvalid, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: inputPadding,
        vertical: inputPadding,
      ),
    );
  }

  // ===========================================================================
  // ICON SIZES
  // ===========================================================================

  static const double iconXS = 16.0;
  static const double iconSM = 20.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;
  static const double iconXL = 48.0;
  static const double iconXXL = 64.0;
  static const double navIconSize = 26.0;
  static const double scanButtonSize = 80.0;

  // ===========================================================================
  // ANIMATION
  // ===========================================================================

  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // ===========================================================================
  // SCREEN DIMENSIONS
  // ===========================================================================

  static const double designWidth = 412.0;
  static const double designHeight = 917.0;

  // ===========================================================================
  // STATUS HELPERS â€” icon + color + label (never color alone)
  // ===========================================================================

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return statusValid;
      case 'invalid':
        return statusInvalid;
      case 'flagged':
        return statusFlagged;
      case 'suspicious':
        return statusSuspicious;
      case 'manual_review':
      case 'manualreview':
        return statusManualReview;
      default:
        return textSecondary;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return Icons.check_circle_rounded;
      case 'invalid':
        return Icons.cancel_rounded;
      case 'flagged':
        return Icons.flag_rounded;
      case 'suspicious':
        return Icons.warning_amber_rounded;
      case 'manual_review':
      case 'manualreview':
        return Icons.manage_search_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  static TextStyle getStatusTextStyle(String status) {
    return statusText.copyWith(color: getStatusColor(status));
  }
}

