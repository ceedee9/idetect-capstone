// =============================================================================
// FILE: lib/presentation/screens/scan/processing_screen.dart
// PURPOSE: Process captured ID image with OCR and display results
// FLOW: OCR -> show extracted fields -> user edits -> Confirm -> VerifyingScreen
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../core/constants/app_design_system.dart';
import '../../../services/enhanced_ocr_service.dart';
import '../../../services/hybrid_parser_service.dart';
import '../../../services/parser_service.dart';
import 'verifying_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String imagePath;
  final String idType; // 'senior' or 'pwd'

  const ProcessingScreen({
    super.key,
    required this.imagePath,
    required this.idType,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final EnhancedOCRService _ocrService = EnhancedOCRService();
  final HybridParserService _hybridParser = HybridParserService();
  final ParserService _parserService = ParserService();

  // Processing state
  ProcessingStep _currentStep = ProcessingStep.analyzing;
  bool _isProcessing = true;
  double _progress = 0.0;

  // Results
  EnhancedOCRResult? _ocrResult;
  ParsedIDData? _parsedData;
  String? _errorMessage;
  String? _ocrEngine;

  // Resolved ID type: same as widget.idType unless 'auto' was selected
  late String _resolvedIdType;

  late AnimationController _animationController;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _resolvedIdType = widget.idType; // may be overwritten during auto-detect
    _animationController = AnimationController(
      vsync: this,
      duration: AppDesignSystem.animationNormal,
    )..repeat();
    _startProcessing();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ocrService.dispose();
    _hybridParser.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ===========================================================================
  // STEP 1 — OCR only. No API call here.
  // ===========================================================================

  Future<void> _startProcessing() async {
    try {
      debugPrint('=== PROCESSING START ===');

      final imageFile = File(widget.imagePath);
      if (!await imageFile.exists()) {
        _handleError('Image file not found: ${widget.imagePath}');
        return;
      }

      // Step 0: Face presence check — fast ML Kit pass before OCR
      setState(() {
        _currentStep = ProcessingStep.analyzing;
        _progress = 0.1;
      });
      final facePresent = await _runFaceCheck(imageFile);
      if (!facePresent) {
        // User chose to recapture — go back to camera
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // Step 1: Analyzing (+ auto-detect card type if requested)
      setState(() {
        _currentStep = ProcessingStep.analyzing;
        _progress = 0.25;
      });

      if (widget.idType == 'auto') {
        debugPrint('🔍 Auto-detecting card type...');
        final detected = await HybridParserService.sniffCardType(imageFile);
        if (detected != null) {
          _resolvedIdType = detected;
          debugPrint('✅ Detected card type: $_resolvedIdType');
        } else {
          // Cannot detect — ask the cashier to confirm
          if (mounted) {
            final chosen = await _showTypeConfirmDialog();
            if (chosen == null) {
              _handleError('Card type could not be determined. Please select manually.');
              return;
            }
            _resolvedIdType = chosen;
          }
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // Step 2: OCR + Hybrid parsing
      setState(() {
        _currentStep = ProcessingStep.extracting;
        _progress = 0.65;
      });

      debugPrint('🔄 Starting HYBRID OCR + Parsing (type: $_resolvedIdType)...');

      try {
        _parsedData = await _hybridParser.parseIDWithHybridApproach(
          imageFile: imageFile,
          idType: _resolvedIdType,
        );
      } catch (e) {
        debugPrint('❌ Hybrid Parser Exception: $e');
        _handleError('Hybrid parsing failed: $e');
        return;
      }

      if (_parsedData == null) {
        _handleError('Hybrid parser returned null result');
        return;
      }

      if (!_parsedData!.success) {
        _handleError(_parsedData!.errorMessage ?? 'Hybrid parsing failed');
        return;
      }

      debugPrint(
          '✅ OCR complete — confidence: ${(_parsedData!.confidence * 100).toInt()}%');
      _ocrEngine = 'ML Kit (with ${_parsedData!.extractionMethod})';

      // Done — show fields for user review
      setState(() {
        _currentStep = ProcessingStep.done;
        _progress = 1.0;
        _isProcessing = false;
      });

      _animationController.stop();
      _initializeControllers();

      debugPrint('=== OCR COMPLETE — awaiting user confirmation ===');
    } catch (e, stackTrace) {
      debugPrint('❌ FATAL ERROR: $e\n$stackTrace');
      _handleError('Processing error: $e');
    }
  }

  // ===========================================================================
  // STEP 1b — Fallback path ("Try Anyway"). Also no API call here.
  // ===========================================================================

  Future<void> _processWithoutQualityCheck() async {
    try {
      setState(() {
        _errorMessage = null;
        _isProcessing = true;
        _currentStep = ProcessingStep.extracting;
        _progress = 0.50;
      });

      final imageFile = File(widget.imagePath);

      _ocrResult = await _ocrService.processIDImage(
        imageFile: imageFile,
        idType: _resolvedIdType,
      );

      if (!_ocrResult!.success) {
        _handleError(
            'Still failed to extract text. Image quality may be too poor.');
        return;
      }

      _ocrEngine = _ocrResult!.engine;

      setState(() {
        _currentStep = ProcessingStep.parsing;
        _progress = 0.75;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      _parsedData = await _parserService.parseIDText(_ocrResult!.rawText);

      if (!_parsedData!.success) {
        _handleError(_parsedData!.errorMessage ?? 'Parsing failed');
        return;
      }

      setState(() {
        _currentStep = ProcessingStep.done;
        _progress = 1.0;
        _isProcessing = false;
      });

      _animationController.stop();
      _initializeControllers();
    } catch (e) {
      _handleError('Processing error: $e');
    }
  }

  void _initializeControllers() {
    _controllers['fullName'] =
        TextEditingController(text: _parsedData?.fullName ?? '');
    _controllers['disabilityType'] =
        TextEditingController(text: _parsedData?.disabilityType ?? '');
    _controllers['age'] =
        TextEditingController(text: _parsedData?.age?.toString() ?? '');
    _controllers['sex'] = TextEditingController(text: _parsedData?.sex ?? '');
    _controllers['dateIssued'] =
        TextEditingController(text: _parsedData?.dateIssued ?? '');
    _controllers['controlNumber'] = TextEditingController(
        text: _parsedData?.controlNumber ?? _parsedData?.idNumber ?? '');
  }

  // ---------------------------------------------------------------------------
  // Face presence check
  // ---------------------------------------------------------------------------

  /// Runs ML Kit FaceDetector on the captured image.
  /// Returns true if a face is found, or if the user chooses to continue anyway.
  /// Returns false if the user chooses to recapture.
  Future<bool> _runFaceCheck(File imageFile) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
    try {
      final input = InputImage.fromFile(imageFile);
      final faces = await detector.processImage(input);
      if (faces.isNotEmpty) return true;
      // No face found — ask cashier
      if (!mounted) return true;
      return await _showNoFaceDialog() ?? false;
    } catch (e) {
      debugPrint('⚠️ Face detection error (non-fatal): $e');
      return true; // On error, don't block OCR
    } finally {
      detector.close();
    }
  }

  /// Dialog shown when no face is detected in the captured image.
  /// Returns true = continue anyway, false/null = recapture.
  Future<bool?> _showNoFaceDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.face_outlined, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text('No Face Detected'),
          ],
        ),
        content: const Text(
          'No ID photo was detected in the captured image.\n\n'
          'The card may not be fully in frame, or the photo area '
          'is obscured. Recapturing is strongly recommended.\n\n'
          'A non-ID image should not be used for verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue Anyway'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Recapture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002E6B),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Shows a simple dialog when auto-detect cannot determine the card type.
  // Returns 'senior', 'pwd', or null (user dismissed without choosing).
  Future<String?> _showTypeConfirmDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Select ID Type'),
        content: const Text(
          'The card type could not be detected automatically. '
          'Please select the correct type to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'senior'),
            child: const Text('Senior Citizen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'pwd'),
            child: const Text('PWD'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _handleError(String message) {
    setState(() {
      _errorMessage = message;
      _isProcessing = false;
      _currentStep = ProcessingStep.error;
    });
    _animationController.stop();
  }

  // ===========================================================================
  // STEP 2 — User taps "Confirm" -> navigate to VerifyingScreen
  // ===========================================================================

  Future<void> _confirm() async {
    // Collect the user-reviewed (possibly corrected) values from the form
    final confirmedControl = _controllers['controlNumber']?.text.trim();
    final isPWD = _resolvedIdType == 'pwd';
    final updatedData = ParsedIDData(
      success: true,
      idType: _parsedData?.idType,
      idNumber: (confirmedControl != null && confirmedControl.isNotEmpty)
          ? confirmedControl
          : (_parsedData?.idNumber ?? ''),
      fullName: _controllers['fullName']?.text,
      disabilityType: isPWD
          ? _controllers['disabilityType']?.text
          : _parsedData?.disabilityType,
      age: isPWD ? null : int.tryParse(_controllers['age']?.text ?? ''),
      sex: isPWD ? null : _controllers['sex']?.text,
      dateIssued: isPWD ? null : _controllers['dateIssued']?.text,
      controlNumber: _controllers['controlNumber']?.text,
      confidence: _parsedData?.confidence ?? 0.0,
      rawText: _ocrResult?.rawText ?? _parsedData?.rawText ?? '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyingScreen(
          parsedData: updatedData,
          imagePath: widget.imagePath,
          idType: _resolvedIdType,
        ),
      ),
    );
  }

  void _retake() => Navigator.of(context).pop();

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        title: const Text('Processing ID'),
        centerTitle: true,
        backgroundColor: AppDesignSystem.primaryBlue,
        foregroundColor: AppDesignSystem.textOnPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDesignSystem.spaceMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePreview(),
              SizedBox(height: AppDesignSystem.spaceMD),
              if (_isProcessing)
                _buildProcessingStatus()
              else if (_errorMessage != null)
                _buildErrorView()
              else
                _buildResultsView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: ClipRRect(
        borderRadius: AppDesignSystem.cardRadius,
        child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildProcessingStatus() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceLG),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 6,
              backgroundColor: AppDesignSystem.backgroundLight,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppDesignSystem.primaryBlue),
            ),
          ),
          SizedBox(height: AppDesignSystem.spaceMD),
          Text(
            '${(_progress * 100).toInt()}%',
            style: AppDesignSystem.heading3
                .copyWith(color: AppDesignSystem.primaryBlue),
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          Text(
            _getStepMessage(_currentStep),
            style:
                AppDesignSystem.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppDesignSystem.spaceXS),
          Text(
            _getStepDescription(_currentStep),
            style: AppDesignSystem.bodyMedium
                .copyWith(color: AppDesignSystem.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppDesignSystem.spaceLG),
          _buildStepIndicators(),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    // Only 3 visual steps now: Analyze → Extract → Done
    final steps = [
      ProcessingStep.analyzing,
      ProcessingStep.extracting,
      ProcessingStep.done,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.map((step) {
        final isCompleted = step.index <= _currentStep.index;
        final isCurrent = step == _currentStep;
        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppDesignSystem.primaryBlue
                    : AppDesignSystem.backgroundLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent
                      ? AppDesignSystem.primaryBlue
                      : AppDesignSystem.borderLight,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: isCompleted
                  ? Icon(Icons.check,
                      size: AppDesignSystem.iconSM,
                      color: AppDesignSystem.textOnPrimary)
                  : Center(
                      child: Text(
                        '${step.index + 1}',
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: AppDesignSystem.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            if (step != steps.last)
              Container(
                width: 24,
                height: 2,
                color: isCompleted
                    ? AppDesignSystem.primaryBlue
                    : AppDesignSystem.borderLight,
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildErrorView() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceLG),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline,
              size: 64, color: AppDesignSystem.statusInvalid),
          SizedBox(height: AppDesignSystem.spaceMD),
          Text('Processing Failed',
              style: AppDesignSystem.heading3
                  .copyWith(color: AppDesignSystem.statusInvalid)),
          SizedBox(height: AppDesignSystem.spaceSM),
          Text(
            _errorMessage ?? 'An unknown error occurred',
            style: AppDesignSystem.bodyMedium
                .copyWith(color: AppDesignSystem.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppDesignSystem.spaceLG),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _retake,
                  style: AppDesignSystem.secondaryButton,
                  child: const Text('Retake Photo'),
                ),
              ),
              SizedBox(width: AppDesignSystem.spaceSM),
              Expanded(
                child: ElevatedButton(
                  onPressed: _processWithoutQualityCheck,
                  style: AppDesignSystem.primaryButton,
                  child: const Text('Try Anyway'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildReviewBanner(),
        SizedBox(height: AppDesignSystem.spaceMD),
        _buildDataFields(),
        SizedBox(height: AppDesignSystem.spaceMD),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildReviewBanner() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: AppDesignSystem.primaryBlue.withOpacity(0.05),
        borderRadius: AppDesignSystem.cardRadius,
        border: Border.all(color: AppDesignSystem.primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.rate_review_outlined,
              color: AppDesignSystem.primaryBlue, size: AppDesignSystem.iconLG),
          SizedBox(width: AppDesignSystem.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Review Extracted Data',
                    style: AppDesignSystem.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppDesignSystem.primaryBlue)),
                SizedBox(height: AppDesignSystem.spaceXXS),
                Text('Please review and correct any errors before confirming.',
                    style: AppDesignSystem.bodyMedium
                        .copyWith(color: AppDesignSystem.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataFields() {
    final isPWD = _resolvedIdType == 'pwd';
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit,
                  size: AppDesignSystem.iconMD,
                  color: AppDesignSystem.primaryBlue),
              SizedBox(width: AppDesignSystem.spaceXS),
              Text('Extracted Data',
                  style: AppDesignSystem.heading4
                      .copyWith(color: AppDesignSystem.primaryBlue)),
            ],
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          Text('Review and correct if needed before confirming:',
              style: AppDesignSystem.bodyMedium
                  .copyWith(color: AppDesignSystem.textSecondary)),
          SizedBox(height: AppDesignSystem.spaceMD),
          _buildInfoRow(
              'ID Type', _parsedData?.idType?.name.toUpperCase() ?? 'Unknown'),
          SizedBox(height: AppDesignSystem.spaceSM),
          _buildEditableField('Full Name', 'fullName', Icons.person),
          SizedBox(height: AppDesignSystem.spaceSM),
          if (isPWD) ...[
            _buildEditableField('Type of Disability', 'disabilityType',
                Icons.accessible_forward),
            SizedBox(height: AppDesignSystem.spaceSM),
            _buildEditableField(
                'ID No.', 'controlNumber', Icons.confirmation_number),
            SizedBox(height: AppDesignSystem.spaceXS),
            Text(
              '* PWD ID No. is sent to the database for verification.',
              style: AppDesignSystem.bodySmall
                  .copyWith(color: AppDesignSystem.textSecondary),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                    child: _buildEditableField('Age', 'age', Icons.cake,
                        keyboardType: TextInputType.number)),
                SizedBox(width: AppDesignSystem.spaceSM),
                Expanded(child: _buildEditableField('Sex', 'sex', Icons.wc)),
              ],
            ),
            SizedBox(height: AppDesignSystem.spaceSM),
            _buildEditableField(
                'Date Issued', 'dateIssued', Icons.calendar_today),
            SizedBox(height: AppDesignSystem.spaceSM),
            _buildEditableField(
                'Control Number', 'controlNumber', Icons.confirmation_number),
            SizedBox(height: AppDesignSystem.spaceXS),
            Text(
              '* Control Number is sent to the database for verification.',
              style: AppDesignSystem.bodySmall
                  .copyWith(color: AppDesignSystem.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: AppDesignSystem.bodyMedium.copyWith(
                  color: AppDesignSystem.textSecondary,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: AppDesignSystem.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildEditableField(String label, String controllerKey, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppDesignSystem.label),
        SizedBox(height: AppDesignSystem.spaceXXS),
        TextField(
          controller: _controllers[controllerKey],
          keyboardType: keyboardType,
          style: AppDesignSystem.bodyMedium,
          decoration: AppDesignSystem.inputDecoration(
              hintText: 'Enter $label', prefixIcon: icon),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _retake,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF002E6B), width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.camera_alt, color: Color(0xFF002E6B)),
            label: const Text('Retake',
                style: TextStyle(
                    color: Color(0xFF002E6B),
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002E6B),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text(
              'Confirm',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _getStepMessage(ProcessingStep step) {
    switch (step) {
      case ProcessingStep.analyzing:
        return 'Analyzing image quality...';
      case ProcessingStep.extracting:
        return 'Extracting text with OCR...';
      case ProcessingStep.parsing:
        return 'Parsing fields...';
      case ProcessingStep.done:
        return 'Done! Review the details below.';
      case ProcessingStep.error:
        return 'Error';
    }
  }

  String _getStepDescription(ProcessingStep step) {
    switch (step) {
      case ProcessingStep.analyzing:
        return 'Verifying image quality and ID photo presence';
      case ProcessingStep.extracting:
        return 'Using AI to read text from the image';
      case ProcessingStep.parsing:
        return 'Identifying name, ID number, and other fields';
      case ProcessingStep.done:
        return 'Correct any errors then tap Confirm';
      case ProcessingStep.error:
        return '';
    }
  }
}

enum ProcessingStep { analyzing, extracting, parsing, done, error }
