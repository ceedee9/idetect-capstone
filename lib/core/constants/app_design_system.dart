// =============================================================================
// FILE: lib/core/constants/app_design_system.dart
// PURPOSE: iDetect Design System - Extracted from Figma
// FIGMA: https://www.figma.com/design/MmFOx2QWDFwQLYZqaN905d/Untitled
// LAST UPDATED: January 15, 2026
// =============================================================================

import 'package:flutter/material.dart';

/// Design System for iDetect ID Verification App
/// All values extracted from Figma design file
///
/// USAGE:
/// Import this file in all UI files:
/// import 'package:idetect/core/constants/app_design_system.dart';
///
/// Use constants instead of hardcoded values:
/// ✅ Container(color: AppDesignSystem.primaryBlue)
/// ❌ Container(color: Color(0xFF002E6B))

class AppDesignSystem {
  AppDesignSystem._(); // Prevents instantiation

  // ===========================================================================
  // BRAND COLORS - From iDetect Logo
  // ===========================================================================

  /// Primary brand color (dark blue from logo)
  static const Color primaryBlue = Color(0xFF002E6B);

  /// Accent color (red from "DETECT" text)
  static const Color accentRed = Color(0xFFE94444);

  /// Secondary blue (lighter shade for interactive elements)
  static const Color secondaryBlue = Color(0xFF5170FF);

  // ===========================================================================
  // STATUS COLORS - For Verification Results
  // ===========================================================================

  /// Valid status (green) - Used when ID verification passes
  static const Color statusValid = Color(0xFF13BB11);

  /// Invalid status (red) - Used when ID verification fails
  static const Color statusInvalid = Color(0xFFFF0000);

  /// Flagged status (orange/red) - Used for suspicious IDs
  static const Color statusFlagged = Color(0xFFFF6B6B);

  // ===========================================================================
  // BACKGROUND COLORS
  // ===========================================================================

  /// Primary background (white) - Used for cards and main surfaces
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  /// Secondary background (light gray) - Used for screens
  static const Color backgroundLight = Color(0xFFF5F5F5);

  /// Dark background - Used for overlays and dark mode
  static const Color backgroundDark = Color(0xFF292D32);

  /// Dark blue background - Used for headers and sections
  static const Color backgroundDarkBlue = Color(0xFF002E6B);

  /// Light blue background - Used for input fields
  static const Color backgroundLightBlue = Color(0xFFF1F4FF);

  // ===========================================================================
  // TEXT COLORS
  // ===========================================================================

  /// Primary text color (black) - Main content text
  static const Color textPrimary = Color(0xFF000000);

  /// Secondary text color (gray) - Subtitles, hints
  static const Color textSecondary = Color(0xFF626262);

  /// Tertiary text color (light gray) - Placeholder text
  static const Color textTertiary = Color(0xFFBDBDBD);

  /// Text on dark backgrounds (white)
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Text on primary color (white)
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ===========================================================================
  // UI ELEMENT COLORS
  // ===========================================================================

  /// Border color (light gray)
  static const Color borderLight = Color(0xFFE0E0E0);

  /// Border color (medium gray)
  static const Color borderMedium = Color(0xFFBDBDBD);

  /// Divider color
  static const Color divider = Color(0xFFEEEEEE);

  /// Icon color (dark gray)
  static const Color iconDark = Color(0xFF404B52);

  /// Icon color on light backgrounds
  static const Color iconLight = Color(0xFF757575);

  // ===========================================================================
  // TYPOGRAPHY - Font Styles
  // ===========================================================================

  /// Font family (system default)
  static const String fontFamily = 'Roboto'; // Android/Windows default

  // ---------------------------------------------------------------------------
  // HEADINGS
  // ---------------------------------------------------------------------------

  /// Display heading (very large) - Used for page titles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  /// Heading 1 - Major section headers
  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  /// Heading 2 - Screen titles (e.g., "SCAN ID CARD")
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textOnDark,
    letterSpacing: 1.5, // Wide spacing for impact
  );

  /// Heading 3 - Section headers (e.g., "Create Account")
  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textOnDark,
  );

  /// Heading 4 - Card titles (e.g., "PDAO", "OSCA")
  static const TextStyle heading4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // ---------------------------------------------------------------------------
  // BODY TEXT
  // ---------------------------------------------------------------------------

  /// Body Large - Main content text
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  /// Body Medium - Standard text
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.4,
  );

  /// Body Small - Helper text, captions
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.3,
  );

  // ---------------------------------------------------------------------------
  // SPECIAL TEXT STYLES
  // ---------------------------------------------------------------------------

  /// Button text - Large buttons
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textOnPrimary,
    letterSpacing: 0.5,
  );

  /// Button text - Medium buttons
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textOnPrimary,
    letterSpacing: 0.3,
  );

  /// Label text - Input field labels
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  /// Caption text - Very small text
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  /// Instruction text - On scan screen
  static const TextStyle instruction = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textOnDark,
    height: 1.4,
  );

  /// Status text - Valid/Invalid labels
  static const TextStyle statusText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ===========================================================================
  // SPACING - Based on 8px grid system
  // ===========================================================================

  /// Base spacing unit (8px)
  static const double spaceUnit = 8.0;

  // Standard spacing values
  static const double spaceXXS = spaceUnit * 0.5; // 4px
  static const double spaceXS = spaceUnit * 1; // 8px
  static const double spaceSM = spaceUnit * 2; // 16px
  static const double spaceMD = spaceUnit * 3; // 24px
  static const double spaceLG = spaceUnit * 4; // 32px
  static const double spaceXL = spaceUnit * 5; // 40px
  static const double spaceXXL = spaceUnit * 6; // 48px

  // Screen padding
  static const double screenPaddingHorizontal = 20.0;
  static const double screenPaddingVertical = 16.0;

  // Component spacing
  static const double cardPadding = 16.0;
  static const double cardSpacing = 12.0;
  static const double buttonPadding = 16.0;
  static const double inputPadding = 16.0;
  static const double sectionSpacing = 32.0;

  // ===========================================================================
  // BORDER RADIUS - Rounded corners
  // ===========================================================================

  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0; // Fully rounded (pill shape)

  // Component-specific radius
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(radiusSM), // 8px - rectangular buttons
  );

  static const BorderRadius inputRadius = BorderRadius.all(
    Radius.circular(radiusMD), // 12px - input fields
  );

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(radiusLG), // 16px - cards
  );

  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(radiusXL), // 24px - bottom sheets
  );

  // ===========================================================================
  // SHADOWS - Elevation levels
  // ===========================================================================

  /// Small shadow - Subtle elevation (cards)
  static List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// Medium shadow - Standard elevation (buttons, modals)
  static List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  /// Large shadow - High elevation (floating elements)
  static List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Colors.black.withOpacity(0.16),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // ===========================================================================
  // BUTTON STYLES - Pre-configured button styles
  // ===========================================================================

  /// Primary button - Main action buttons (Sign in, Scan ID, etc.)
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: textOnPrimary,
    padding: const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 16,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: buttonRadius,
    ),
    elevation: 2,
    textStyle: buttonMedium,
    minimumSize: const Size(double.infinity, 56), // Full width, 56px height
  );

  /// Secondary button - Less prominent actions
  static ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: primaryBlue,
    side: const BorderSide(color: primaryBlue, width: 2),
    padding: const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 16,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: buttonRadius,
    ),
    textStyle: buttonMedium,
    minimumSize: const Size(double.infinity, 56),
  );

  /// Text button - Tertiary actions (Forgot password, links)
  static ButtonStyle textButton = TextButton.styleFrom(
    foregroundColor: primaryBlue,
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w600),
  );

  // ===========================================================================
  // INPUT FIELD DECORATION - Text input styling
  // ===========================================================================

  /// Standard input decoration
  static InputDecoration inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: bodyMedium.copyWith(color: textTertiary),
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: iconLight) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: backgroundLightBlue,
      border: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
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

  // Bottom navigation icons
  static const double navIconSize = 28.0;

  // Scan button icon (large circular button)
  static const double scanButtonSize = 80.0;

  // ===========================================================================
  // ANIMATION DURATIONS
  // ===========================================================================

  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // ===========================================================================
  // SCREEN DIMENSIONS (from Figma)
  // ===========================================================================

  static const double designWidth = 412.0;
  static const double designHeight = 917.0;

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// Get status color based on status string
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return statusValid;
      case 'invalid':
        return statusInvalid;
      case 'flagged':
        return statusFlagged;
      default:
        return textSecondary;
    }
  }

  /// Get status icon based on status string
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return Icons.check_circle;
      case 'invalid':
        return Icons.cancel;
      case 'flagged':
        return Icons.flag;
      default:
        return Icons.help;
    }
  }

  /// Get status text style with appropriate color
  static TextStyle getStatusTextStyle(String status) {
    return statusText.copyWith(
      color: getStatusColor(status),
    );
  }
}

// =============================================================================
// USAGE EXAMPLES
// =============================================================================

/*
// ============= COLORS =============
Container(
  color: AppDesignSystem.primaryBlue,
  child: Text(
    'iDetect',
    style: TextStyle(color: AppDesignSystem.textOnPrimary),
  ),
)

// ============= TYPOGRAPHY =============
Text(
  'Welcome to iDetect',
  style: AppDesignSystem.heading1,
)

Text(
  'Scan your ID to verify',
  style: AppDesignSystem.bodyMedium,
)

// ============= SPACING =============
Padding(
  padding: EdgeInsets.all(AppDesignSystem.spaceMD), // 24px
  child: Column(
    children: [
      Widget1(),
      SizedBox(height: AppDesignSystem.spaceSM), // 16px spacing
      Widget2(),
    ],
  ),
)

// ============= BUTTONS =============
ElevatedButton(
  style: AppDesignSystem.primaryButton,
  onPressed: () {},
  child: Text('Sign In'),
)

// ============= INPUT FIELDS =============
TextField(
  decoration: AppDesignSystem.inputDecoration(
    hintText: 'Email',
    prefixIcon: Icons.email,
  ),
)

// ============= STATUS DISPLAY =============
Container(
  padding: EdgeInsets.symmetric(
    horizontal: AppDesignSystem.spaceSM,
    vertical: AppDesignSystem.spaceXS,
  ),
  decoration: BoxDecoration(
    color: AppDesignSystem.getStatusColor('valid'),
    borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        AppDesignSystem.getStatusIcon('valid'),
        size: AppDesignSystem.iconSM,
        color: AppDesignSystem.textOnPrimary,
      ),
      SizedBox(width: AppDesignSystem.spaceXS),
      Text(
        'Valid',
        style: AppDesignSystem.getStatusTextStyle('valid'),
      ),
    ],
  ),
)

// ============= CARDS =============
Container(
  padding: EdgeInsets.all(AppDesignSystem.cardPadding),
  decoration: BoxDecoration(
    color: AppDesignSystem.backgroundWhite,
    borderRadius: AppDesignSystem.cardRadius,
    boxShadow: AppDesignSystem.shadowMD,
  ),
  child: YourContent(),
)
*/
