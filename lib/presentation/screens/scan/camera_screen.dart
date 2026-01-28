// =============================================================================
// FILE: lib/presentation/screens/scan/camera_screen.dart
// PURPOSE: Camera screen with ID card auto-framing and capture
// FEATURES: Clear UI with visible capture button, ID framing guides
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_design_system.dart';
import 'processing_screen.dart';

/// Camera screen with clear capture button and ID framing
class CameraScreen extends StatefulWidget {
  final String idType; // 'senior' or 'pwd'

  const CameraScreen({super.key, required this.idType});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _flashEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Find back camera
      CameraDescription? backCamera;
      for (var camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          break;
        }
      }

      final selectedCamera = backCamera ?? _cameras!.first;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      if (_flashEnabled) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() => _flashEnabled = !_flashEnabled);
    } catch (e) {
      _showError('Flash toggle failed');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    try {
      setState(() => _isCapturing = true);

      if (_flashEnabled) {
        await _cameraController!.setFlashMode(FlashMode.auto);
      }

      final XFile photo = await _cameraController!.takePicture();
      await _processImage(File(photo.path));
    } catch (e) {
      _showError('Capture failed: $e');
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to process image');
      }

      // Auto-crop to ID ratio
      final croppedImage = _autoCropID(image);

      // Save processed image
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedPath = '${tempDir.path}/id_${timestamp}_processed.jpg';
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(
        img.encodeJpg(croppedImage, quality: 95),
      );

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessingScreen(
              imagePath: processedPath,
              idType: widget.idType,
            ),
          ),
        );
        // Reset capturing state when returning from processing
        if (mounted) {
          setState(() => _isCapturing = false);
        }
      }
    } catch (e) {
      _showError('Processing failed: $e');
      setState(() => _isCapturing = false);
    }
  }

  img.Image _autoCropID(img.Image image) {
    const targetRatio = 1.586;
    final imageRatio = image.width / image.height;

    if ((imageRatio - targetRatio).abs() < 0.1) {
      return image;
    }

    int cropWidth = image.width;
    int cropHeight = image.height;

    if (imageRatio > targetRatio) {
      cropWidth = (image.height * targetRatio).toInt();
    } else {
      cropHeight = (image.width / targetRatio).toInt();
    }

    final x = (image.width - cropWidth) ~/ 2;
    final y = (image.height - cropHeight) ~/ 2;

    return img.copyCrop(image,
        x: x, y: y, width: cropWidth, height: cropHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_isInitialized && _cameraController != null)
            Center(
              child: CameraPreview(_cameraController!),
            )
          else
            _buildLoadingState(),

          // ID Frame Overlay
          _buildFrameOverlay(),

          // Top Bar
          _buildTopBar(),

          // Bottom Controls
          _buildBottomControls(),

          // Capture Progress
          if (_isCapturing) _buildCaptureProgress(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppDesignSystem.primaryBlue),
          SizedBox(height: AppDesignSystem.spaceMD),
          Text(
            'Initializing camera...',
            style: AppDesignSystem.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameOverlay() {
    return CustomPaint(
      painter: _IDFramePainter(),
      child: Container(),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppDesignSystem.spaceMD),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close button
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              color: Colors.white,
              iconSize: 32,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
              ),
            ),
            // Instructions
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.spaceSM,
                vertical: AppDesignSystem.spaceXS,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.idType == 'senior' ? 'Senior Citizen ID' : 'PWD ID',
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Flash toggle
            if (_isInitialized)
              IconButton(
                onPressed: _toggleFlash,
                icon: Icon(_flashEnabled ? Icons.flash_on : Icons.flash_off),
                color: _flashEnabled ? Colors.yellow : Colors.white,
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.all(AppDesignSystem.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tips
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.spaceSM,
                  vertical: AppDesignSystem.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'Position ID card within the frame',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ensure text is clear and readable',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppDesignSystem.spaceLG),

              // CAPTURE BUTTON (Large and Obvious)
              GestureDetector(
                onTap: _isInitialized && !_isCapturing ? _capturePhoto : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF002E6B), // Blue color
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Colors.white,
                        ),
                ),
              ),
              SizedBox(height: AppDesignSystem.spaceSM),

              // Capture label
              Text(
                _isCapturing ? 'Processing...' : 'TAP TO CAPTURE',
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureProgress() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF002E6B)),
            SizedBox(height: AppDesignSystem.spaceMD),
            Text(
              'Processing image...',
              style: AppDesignSystem.bodyMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for ID frame overlay
class _IDFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate frame position (centered)
    const frameWidth = 340.0;
    const frameHeight = 214.0;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    final frameRect = Rect.fromLTWH(left, top, frameWidth, frameHeight);

    // Draw dark overlay except frame area
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withOpacity(0.6),
    );

    // Draw green frame border
    final framePaint = Paint()
      ..color = const Color(0xFF4CAF50) // Softer green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      framePaint,
    );

    // Draw corner guides
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = const Color(0xFF4CAF50) // Softer green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top),
      Offset(left + frameWidth, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + frameWidth, top),
      Offset(left + frameWidth, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, top + frameHeight - cornerLength),
      Offset(left, top + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + frameHeight),
      Offset(left + cornerLength, top + frameHeight),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top + frameHeight),
      Offset(left + frameWidth, top + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + frameWidth, top + frameHeight - cornerLength),
      Offset(left + frameWidth, top + frameHeight),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
