// =============================================================================
// FILE: lib/presentation/widgets/ledger_lines_painter.dart
// PURPOSE: Subtle "ledger paper" texture — thin horizontal rule lines
// plus a single vertical margin line, like classic ruled ledger/
// notebook paper. Distinct from GuillochePainter (the "security
// document" motif used on login/camera/review) — this one signals
// "form / record being filled out or verified", so it's used on
// screens like processing (reviewing extracted ID data) rather than
// ID-capture moments.
// =============================================================================

import 'package:flutter/material.dart';

class LedgerLinesPainter extends CustomPainter {
  const LedgerLinesPainter({
    this.lineColor = const Color(0xFF00225F),
    this.marginColor = const Color(0xFFB33A2E),
    this.lineSpacing = 28,
    this.marginInset = 40,
  });

  final Color lineColor;
  final Color marginColor;
  final double lineSpacing;
  final double marginInset;

  @override
  void paint(Canvas canvas, Size size) {
    final rulePaint = Paint()
      ..color = lineColor.withOpacity(0.05)
      ..strokeWidth = 1;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
    }

    final marginPaint = Paint()
      ..color = marginColor.withOpacity(0.10)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(marginInset, 0),
      Offset(marginInset, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LedgerLinesPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.marginColor != marginColor ||
      oldDelegate.lineSpacing != lineSpacing ||
      oldDelegate.marginInset != marginInset;
}
