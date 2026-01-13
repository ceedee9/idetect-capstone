// =============================================================================
// FILE: lib/presentation/screens/scan/camera_screen.dart
// PURPOSE: Camera capture screen for scanning Senior Citizen and PWD IDs
// FEATURES: Camera preview, capture button, gallery picker, image preview
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Camera controller
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  // Image picker for gallery
  final ImagePicker _imagePicker = ImagePicker();

  // Captured image
  File? _capturedImage;

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

  // =============================================================================
  // CAMERA INITIALIZATION
  // =============================================================================

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();

    if (status.isDenied) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        _showNoCameraDialog();
        return;
      }

      // Initialize camera controller with back camera
      _cameraController = CameraController(
        _cameras![0], // Use back camera (index 0)
        ResolutionPreset.high, // High resolution for OCR accuracy
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _showCameraErrorDialog(e.toString());
    }
  }

  // =============================================================================
  // CAPTURE IMAGE FROM CAMERA
  // =============================================================================

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Take picture
      final XFile photo = await _cameraController!.takePicture();

      setState(() {
        _capturedImage = File(photo.path);
      });

      // TODO: Process image with OCR (Next step)
      // For now, just show preview
      _showImagePreview();
    } catch (e) {
      debugPrint('Error capturing image: $e');
      _showErrorSnackBar('Failed to capture image');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // =============================================================================
  // PICK IMAGE FROM GALLERY
  // =============================================================================

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Maximum quality for OCR
      );

      if (pickedFile != null) {
        setState(() {
          _capturedImage = File(pickedFile.path);
        });

        _showImagePreview();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image');
    }
  }

  // =============================================================================
  // IMAGE PREVIEW AFTER CAPTURE
  // =============================================================================

  void _showImagePreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ID Captured'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_capturedImage != null)
              Image.file(
                _capturedImage!,
                height: 300,
                fit: BoxFit.contain,
              ),
            const SizedBox(height: 16),
            const Text('Process this image?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _capturedImage = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Retake'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processImage();
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // PROCESS IMAGE (OCR - TO BE IMPLEMENTED)
  // =============================================================================

  void _processImage() {
    if (_capturedImage == null) return;

    // TODO: Implement OCR processing here
    // For now, navigate to processing screen with the image

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(imagePath: _capturedImage!.path),
      ),
    );
  }

  // =============================================================================
  // UI HELPER METHODS
  // =============================================================================

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Denied'),
        content: const Text(
          'iDetect needs camera access to scan IDs. Please enable camera permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showNoCameraDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Camera Found'),
        content: const Text('No camera detected on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCameraErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Error'),
        content: Text('Failed to initialize camera: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // =============================================================================
  // BUILD UI
  // =============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan ID'),
        centerTitle: true,
      ),
      body: _isCameraInitialized ? _buildCameraView() : _buildLoadingView(),
    );
  }

  // Camera loading view
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing camera...'),
        ],
      ),
    );
  }

  // Main camera view
  Widget _buildCameraView() {
    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),

        // ID frame guide overlay
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.credit_card, size: 80, color: Colors.white54),
                SizedBox(height: 16),
                Text(
                  'Align ID within frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Top instruction bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Position ID card flat and ensure good lighting',
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Bottom control buttons
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                _buildControlButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onPressed: _pickImageFromGallery,
                ),

                // Capture button
                _buildCaptureButton(),

                // Flash toggle button
                _buildControlButton(
                  icon: Icons.flash_on,
                  label: 'Flash',
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),
        ),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  // Control button widget
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
          color: Colors.white,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  // Capture button (larger, centered)
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _captureImage,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.blue, width: 4),
        ),
        child: const Icon(
          Icons.camera,
          size: 40,
          color: Colors.blue,
        ),
      ),
    );
  }

  // Flash toggle
  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      final currentFlashMode = _cameraController!.value.flashMode;

      if (currentFlashMode == FlashMode.off) {
        await _cameraController!.setFlashMode(FlashMode.torch);
        _showErrorSnackBar('Flash ON');
      } else {
        await _cameraController!.setFlashMode(FlashMode.off);
        _showErrorSnackBar('Flash OFF');
      }
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }
}

// =============================================================================
// PLACEHOLDER PROCESSING SCREEN (TO BE IMPLEMENTED)
// =============================================================================

class ProcessingScreen extends StatelessWidget {
  final String imagePath;

  const ProcessingScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing ID'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Extracting ID information...',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            Image.file(
              File(imagePath),
              height: 300,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const Text(
              'TODO: Implement OCR processing',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
