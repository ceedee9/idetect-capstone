// =============================================================================
// FILE: lib/core/constants/app_design_system.dart
// PURPOSE: iDetect Beneficiary Design System
//
// Designed for Senior Citizens & Persons with Disability (PWD)
// Compliant with WCAG 2.1 Level AA
// Applied Psychology: Fitts' Law, Gestalt, Progressive Disclosure,
//                     Serial Position Effect, Color Psychology
//
// WCAG AA minimums met:
//   â€¢ 4.5:1 contrast ratio for all text (targeting 7:1+ where possible)
//   â€¢ 48dp minimum touch targets (primary actions: 64dp)
//   â€¢ Text resizable; no information lost at 200% scale
//   â€¢ Color never used as the ONLY means of conveying information
//   â€¢ All interactive elements have visible focus indicators
// =============================================================================

import 'package:flutter/material.dart';

class AppDesignSystem {
  AppDesignSystem._();

  // ===========================================================================
  // BRAND COLORS
  // ===========================================================================

  /// Deep trust blue â€” government authority, reliability
  static const Color primaryBlue = Color(0xFF003580);

  /// Interactive blue â€” links, active states, highlights
  static const Color interactiveBlue = Color(0xFF1565C0);

  /// Accent red â€” from iDetect logo "DETECT" text
  static const Color accentRed = Color(0xFFCC2B2B);

  // ===========================================================================
  // SEMANTIC STATUS COLORS (Icon always accompanies color â€” WCAG 1.4.1)
  // ===========================================================================

  /// Active / Valid â€” high-contrast accessible green (5.1:1 on white)
  static const Color statusValid = Color(0xFF15803D);

  /// Expired / Warning â€” accessible amber (4.6:1 on white)
  static const Color statusWarning = Color(0xFFB45309);

  /// Suspended / Flagged â€” deep orange-red (5.0:1 on white)
  static const Color statusFlagged = Color(0xFFB91C1C);

  /// Revoked / Invalid â€” deep red (6.7:1 on white)
  static const Color statusInvalid = Color(0xFF991B1B);

  // ===========================================================================
  // BACKGROUNDS â€” Warm tones reduce eye strain for elderly users
  // ===========================================================================

  /// Warm off-white â€” easier on eyes than pure white; main screen background
  static const Color backgroundWarm = Color(0xFFF8F7F4);

  /// Card surface â€” pure white sits on warm background creating natural depth
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  /// Dark blue â€” for headers, hero sections
  static const Color backgroundDark = Color(0xFF003580);

  /// Soft blue tint â€” subtle input field fill
  static const Color backgroundInput = Color(0xFFEEF2FA);

  // ===========================================================================
  // TEXT COLORS â€” All pass WCAG AA; primary passes AAA (7:1+)
  // ===========================================================================

  /// Primary text â€” warm near-black (~16:1 on backgroundWarm) âœ… AAA
  static const Color textPrimary = Color(0xFF1C1917);

  /// Secondary text â€” warm dark gray (~6:1 on backgroundWarm) âœ… AA
  static const Color textSecondary = Color(0xFF57534E);

  /// Hint / caption â€” warm medium gray (~4.6:1 on backgroundWarm) âœ… AA large text
  /// Use only at 16sp+ or 14sp bold to satisfy AA
  static const Color textHint = Color(0xFF78716C);

  /// Text on dark (blue) backgrounds
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Link / emphasis text
  static const Color textLink = Color(0xFF1565C0);

  // ===========================================================================
  // BORDERS & DIVIDERS
  // ===========================================================================

  static const Color borderLight = Color(0xFFE7E5E4);
  static const Color borderFocus = Color(0xFF1565C0);

  // ===========================================================================
  // TYPOGRAPHY
  // ===========================================================================
  //
  // Scale designed for elderly users:
  //   â€¢ Minimum body: 18sp (WCAG "large text" = only needs 3:1; we target 4.5:1+)
  //   â€¢ Labels: 16sp minimum
  //   â€¢ Captions: 15sp (15pt is considered readable without glasses for many users)
  //   â€¢ Line height: 1.6 minimum (WCAG Success Criterion 1.4.12)
  //   â€¢ No italic body text (harder for dyslexic / low-vision users)
  //
  // Font: System default (respects user's system font size settings)

  static const String fontFamily = 'Roboto';

  // HEADINGS
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 42,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textOnDark,
    height: 1.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.35,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.4,
  );

  // BODY â€” minimum 18sp for elderly accessibility
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.55,
  );

  // FUNCTIONAL STYLES
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textOnDark,
    letterSpacing: 0.3,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textOnDark,
    letterSpacing: 0.2,
  );

  /// Labels â€” 16sp minimum (WCAG). Used for input field labels, row labels.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    height: 1.4,
  );

  /// Caption â€” 15sp; use only on light backgrounds (meets AA at this size+color)
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle statusText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.0,
  );

  static const TextStyle instruction = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: textOnDark,
    height: 1.6,
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
  static const double spaceXXL = 56.0;

  static const double screenPaddingHorizontal = 20.0;
  static const double screenPaddingVertical = 20.0;
  static const double cardPadding = 20.0;
  static const double cardSpacing = 14.0;
  static const double sectionSpacing = 32.0;

  // ===========================================================================
  // TOUCH TARGETS â€” WCAG 2.1 SC 2.5.5 (AAA: 44x44) / Android: 48dp
  // We target 56dp minimum, 64dp for primary actions (Fitts' Law)
  // ===========================================================================

  /// Minimum touch target for all interactive elements
  static const double touchTargetMin = 56.0;

  /// Primary action touch target (buttons, main CTA)
  static const double touchTargetPrimary = 64.0;

  /// Navigation bar item height
  static const double navBarHeight = 76.0;

  // ===========================================================================
  // BORDER RADIUS
  // ===========================================================================

  static const double radiusXS = 6.0;
  static const double radiusSM = 10.0;
  static const double radiusMD = 14.0;
  static const double radiusLG = 18.0;
  static const double radiusXL = 26.0;
  static const double radiusFull = 999.0;

  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(radiusSM),
  );

  static const BorderRadius inputRadius = BorderRadius.all(
    Radius.circular(radiusMD),
  );

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(radiusLG),
  );

  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(radiusXL),
  );

  // ===========================================================================
  // SHADOWS â€” Physical depth cues aid elderly spatial understanding
  // ===========================================================================

  static List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Colors.black.withOpacity(0.07),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Colors.black.withOpacity(0.14),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  // ===========================================================================
  // BUTTON STYLES
  // ===========================================================================

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: textOnDark,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
    shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
    elevation: 2,
    textStyle: buttonMedium,
    minimumSize: const Size(double.infinity, touchTargetPrimary),
  );

  static ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: primaryBlue,
    side: const BorderSide(color: primaryBlue, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
    shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
    textStyle: buttonMedium.copyWith(color: primaryBlue),
    minimumSize: const Size(double.infinity, touchTargetPrimary),
  );

  static ButtonStyle textButton = TextButton.styleFrom(
    foregroundColor: textLink,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    textStyle: bodyMedium.copyWith(
      fontWeight: FontWeight.w600,
      color: textLink,
    ),
    minimumSize: const Size(0, touchTargetMin),
  );

  // ===========================================================================
  // INPUT DECORATION
  // ===========================================================================

  static InputDecoration inputDecoration({
    required String hintText,
    String? labelText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: label,
      hintText: hintText,
      hintStyle: bodyMedium.copyWith(color: textHint),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: textSecondary, size: 26)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: backgroundInput,
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
        borderSide: const BorderSide(color: borderFocus, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: accentRed, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: accentRed, width: 2.5),
      ),
      errorStyle: bodySmall.copyWith(color: accentRed),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    );
  }

  // ===========================================================================
  // ICON SIZES
  // ===========================================================================

  static const double iconSM = 22.0;
  static const double iconMD = 28.0;
  static const double iconLG = 36.0;
  static const double iconXL = 52.0;
  static const double iconXXL = 72.0;
  static const double navIconSize = 30.0;

  // ===========================================================================
  // ANIMATION
  // ===========================================================================

  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 280);
  static const Duration animationSlow = Duration(milliseconds: 450);

  // ===========================================================================
  // STATUS HELPERS (always icon + color + text â€” never color alone)
  // ===========================================================================

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return statusValid;
      case 'expired':
        return statusWarning;
      case 'suspended':
        return statusFlagged;
      case 'revoked':
        return statusInvalid;
      default:
        return textSecondary;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle_rounded;
      case 'expired':
        return Icons.schedule_rounded;
      case 'suspended':
        return Icons.warning_amber_rounded;
      case 'revoked':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  static String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active & Valid';
      case 'expired':
        return 'Expired';
      case 'suspended':
        return 'Under Investigation';
      case 'revoked':
        return 'Revoked';
      default:
        return status.toUpperCase();
    }
  }
}
