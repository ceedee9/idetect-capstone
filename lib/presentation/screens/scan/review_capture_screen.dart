// =============================================================================
// FILE: lib/presentation/screens/scan/review_capture_screen.dart
// PURPOSE: Post-capture review step between CameraScreen and ProcessingScreen.
// Lets staff catch a bad photo (blur, glare, ID out of frame) before
// committing to the OCR pipeline, and surfaces the seal-detection result
// that CameraScreen._processImage already computes but previously discarded.
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'processing_screen.dart';
import '../../widgets/app_notice.dart';
import '../../widgets/guilloche_painter.dart';

class ReviewCaptureScreen extends StatelessWidget {
  const ReviewCaptureScreen({
    super.key,
    required this.imagePath,
    required this.idType,
    required this.idFormat,
    required this.sealDetected,
  });

  final String imagePath;
  final String idType;
  final String idFormat;
  final bool? sealDetected;

  static const _institutional = Color(0xFF00225F);
  static const _panelBg = Color(0xFF0B1220);
  static const _pageBg = Color(0xFF05070D);

  String get _idTypeLabel {
    switch (idType) {
      case 'senior':
        return 'Senior Citizen ID';
      case 'pwd':
        return 'PWD ID';
      default:
        return 'ID Document';
    }
  }

  void _useThisPhoto(BuildContext context) {
    // Replace (not push) so the back stack goes straight from
    // CameraScreen to ProcessingScreen once committed — matches the
    // original single-push behavior, this review step doesn't linger
    // in history.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(
          imagePath: imagePath,
          idType: idType,
          idFormat: idFormat,
          sealDetected: sealDetected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          // Same security-document texture as the login screen — ties
          // this screen visually to the same family, and thematically
          // it's an even better fit here (this is the actual moment of
          // reviewing a captured ID).
          Positioned.fill(
            child: CustomPaint(
              painter: const GuillochePainter(baseColor: Color(0xFF8FA9DD)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header band — replaces the bare floating text with
                // an actual masthead, and reuses the idType context
                // (shown as a pill on the camera screen) so it isn't
                // lost once the user lands here.
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(context), // → back to camera, retake
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            _idTypeLabel.toUpperCase(),
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'REVIEW CAPTURE',
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white54,
                              fontSize: 9,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                          width: 48), // balances the close button visually
                    ],
                  ),
                ),

                // ── Captured image, presented as a framed object
                // (border + shadow) rather than a raw photo floating
                // on black — reads like the ID is on an inspection
                // table, not just an image preview.
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(File(imagePath), fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),

                // Quality-check warning — shown when the seal wasn't
                // detected OR detection was inconclusive (null). Uses
                // the shared AppNotice widget (same one used on
                // change_password_screen.dart), with onDarkSurface:
                // true since this screen sits on a dark background.
                if (idType != 'auto' && sealDetected != true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: AppNotice(
                      type: AppNoticeType.warning,
                      onDarkSurface: true,
                      message:
                          'Government seal not detected — the ID may be out of '
                          'frame, glared, or blurry. Consider retaking.',
                    ),
                  ),

                // ── Bottom action panel — a raised surface rather
                // than buttons floating directly on black, separating
                // "reviewing" from "acting" the same way a bottom
                // sheet would.
                Container(
                  decoration: BoxDecoration(
                    color: _panelBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.refresh_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'RETAKE',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => _useThisPhoto(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _institutional,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'USE THIS PHOTO',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }
}
