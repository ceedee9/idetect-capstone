// =============================================================================
// FILE: lib/presentation/widgets/app_notice.dart
// PURPOSE: Shared inline notice — left-border-accent + mono uppercase
// label, matching the idiom used on the web login's Notice component.
// Use this anywhere in the app that needs an inline success/error/
// info/warning message instead of a screen defining its own version.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppNoticeType { success, error, info, warning }

class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.type,
    required this.message,
    this.onDarkSurface = false,
    this.label,
  });

  final AppNoticeType type;
  final String message;

  /// Set true when placing this over a dark/black background (e.g. the
  /// camera/review screens) — swaps to a translucent-on-dark treatment
  /// instead of the default light-panel style meant for white screens.
  final bool onDarkSurface;

  /// Overrides the type's default label (e.g. show "ID Type
  /// Auto-Corrected" with the warning color scheme instead of the
  /// default "Quality Check" label). Omit to use the type's default.
  final String? label;

  static const _styles = {
    AppNoticeType.success: (
      accent: Color(0xFF15803D),
      lightBg: Color(0xFFF0FDF4),
      darkBg: Color(0xFF0F2A1B),
      icon: Icons.check_circle_outline_rounded,
      label: 'Success',
    ),
    AppNoticeType.error: (
      accent: Color(0xFFDC2626),
      lightBg: Color(0xFFFFF1F2),
      darkBg: Color(0xFF3A1414),
      icon: Icons.error_outline_rounded,
      label: 'Error',
    ),
    AppNoticeType.info: (
      accent: Color(0xFF00225F),
      lightBg: Color(0xFFEEF2FA),
      darkBg: Color(0xFF101B33),
      icon: Icons.info_outline_rounded,
      label: 'Notice',
    ),
    AppNoticeType.warning: (
      accent: Color(0xFFF5A623),
      lightBg: Color(0xFFFFF7E6),
      darkBg: Color(0xFF3A2E00),
      icon: Icons.warning_amber_rounded,
      label: 'Quality Check',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final s = _styles[type]!;
    final bg = onDarkSurface ? s.darkBg : s.lightBg;
    final messageColor = onDarkSurface
        ? Colors.white.withOpacity(0.85)
        : const Color(0xFF334155);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: s.accent, width: 3)),
        borderRadius: onDarkSurface ? BorderRadius.circular(4) : null,
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
                  (label ?? s.label).toUpperCase(),
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
                  style:
                      TextStyle(fontSize: 13, color: messageColor, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
