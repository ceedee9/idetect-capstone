// =============================================================================
// FILE: lib/presentation/widgets/guilloche_painter.dart
// PURPOSE: Shared "security document" texture — the same guilloché
// motif used on the web login's header band, reimplemented as a
// CustomPainter (Flutter has no built-in inline-SVG rendering without
// adding flutter_svg). Extracted from login_screen.dart so any screen
// that wants this texture (login, review capture, etc.) draws from one
// definition instead of each screen redefining its own copy.
// =============================================================================

import 'package:flutter/material.dart';

class GuillochePainter extends CustomPainter {
  const GuillochePainter({this.baseColor = const Color(0xFF8FA9DD)});

  /// The two wave layers are drawn at 7% and 5% opacity of this color
  /// (and a slightly deeper tint for the second layer) — pass a light
  /// blue-white on dark navy/black backgrounds, or a dark navy on
  /// light backgrounds.
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    _drawLayer(
      canvas,
      size,
      wavelength: 96,
      amplitude: 22,
      rowSpacing: 40,
      phaseShift: 0,
      color: baseColor.withOpacity(0.07),
      strokeWidth: 0.8,
    );
    _drawLayer(
      canvas,
      size,
      wavelength: 96,
      amplitude: 22,
      rowSpacing: 40,
      phaseShift: 20,
      color: baseColor.withOpacity(0.05),
      strokeWidth: 0.6,
    );
  }

  void _drawLayer(
    Canvas canvas,
    Size size, {
    required double wavelength,
    required double amplitude,
    required double rowSpacing,
    required double phaseShift,
    required Color color,
    required double strokeWidth,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (double rowY = phaseShift - amplitude;
        rowY < size.height + amplitude;
        rowY += rowSpacing) {
      final path = Path()..moveTo(-wavelength, rowY);
      for (double x = -wavelength;
          x < size.width + wavelength;
          x += wavelength) {
        path.relativeQuadraticBezierTo(
            wavelength / 2, -amplitude, wavelength, 0);
        path.relativeQuadraticBezierTo(
            wavelength / 2, amplitude, wavelength, 0);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GuillochePainter oldDelegate) =>
      oldDelegate.baseColor != baseColor;
}
