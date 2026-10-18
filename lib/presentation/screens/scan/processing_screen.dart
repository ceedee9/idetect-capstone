// =============================================================================
// FILE: lib/presentation/screens/scan/processing_screen.dart
// PURPOSE: Process captured ID image with OCR and display results
// FLOW: OCR -> show extracted fields -> user edits -> Confirm -> VerifyingScreen
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../../../core/constants/app_design_system.dart';
import '../../../services/enhanced_ocr_service.dart';
import '../../../services/hybrid_parser_service.dart';
import '../../../services/parser_service.dart';
import '../../../services/seal_presence_detector.dart';
import '../../widgets/app_notice.dart';
import '../../widgets/ledger_lines_painter.dart';
import 'verifying_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String imagePath;
  final String idType; // 'senior' or 'pwd'
  final String idFormat; // 'old' or 'new'
  final bool? sealDetected;

  const ProcessingScreen({
    super.key,
    required this.imagePath,
    required this.idType,
    this.idFormat = 'old',
    this.sealDetected,
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

  // Gap 5: true when the OCR pipeline exceeded 20 s and fell back to ML Kit only.
  bool _isTimeoutFallback = false;

  // Gap 6: true when OCR header keywords contradict the cashier's manual type selection.
  bool _typeWasCorrected = false;
  String _originalIdType = ''; // the type the cashier originally chose

  // Resolved ID type: same as widget.idType unless 'auto' was selected
  late String _resolvedIdType;
  late String _resolvedIdFormat;
  bool? _resolvedSealDetected;

  late AnimationController _animationController;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _resolvedIdType = widget.idType; // may be overwritten during auto-detect
    _resolvedIdFormat = widget.idFormat;
    _resolvedSealDetected = widget.sealDetected;
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
              _handleError(
                  'Card type could not be determined. Please select manually.');
              return;
            }
            _resolvedIdType = chosen;
          }
        }

        // Auto mode does not know the beneficiary type when the camera
        // captures the image, so the camera cannot choose the correct seal
        // calibration. Recheck it now with the resolved card type and use
        // the result to select the format-specific parser.
        final bytes = await imageFile.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image != null) {
          final sealResult = await SealPresenceDetector.checkSeal(
            imagePath: imageFile.path,
            imageWidth: image.width,
            imageHeight: image.height,
            beneficiaryType: _resolvedIdType,
          );
          _resolvedSealDetected = sealResult.sealDetected;
          _resolvedIdFormat = sealResult.sealDetected == true ? 'new' : 'old';
          debugPrint(
              '✅ Auto-detected $_resolvedIdType ${_resolvedIdFormat.toUpperCase()} format');
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // Step 2: OCR + Hybrid parsing
      setState(() {
        _currentStep = ProcessingStep.extracting;
        _progress = 0.65;
      });

      debugPrint(
          '🔄 Starting HYBRID OCR + Parsing (type: $_resolvedIdType)...');

      try {
        // Gap 5: 20-second hard timeout on the full hybrid OCR pipeline.
        // If Tesseract stalls (common on low-RAM devices), the timeout fires
        // and we fall back to a fast ML Kit-only pass so the UI never freezes.
        _parsedData = await _hybridParser
            .parseIDWithHybridApproach(
          imageFile: imageFile,
          idType: _resolvedIdType,
          idFormat: _resolvedIdFormat,
        )
            .timeout(
          const Duration(seconds: 20),
          onTimeout: () async {
            debugPrint('⏱️ OCR exceeded 20 s — falling back to ML Kit only');
            _isTimeoutFallback = true;
            return _hybridParser.parseMlKitOnly(imageFile, _resolvedIdType);
          },
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
          '✅ OCR complete — extraction quality: ${(_parsedData!.confidence * 100).toInt()}%');
      _ocrEngine = 'ML Kit (with ${_parsedData!.extractionMethod})';

      // Gap 6: When the cashier pre-selected a type manually (not 'auto'),
      // cross-check the OCR header keywords against that selection.
      // If they disagree, silently correct _resolvedIdType so the right
      // beneficiary_type is sent to the API.
      if (widget.idType != 'auto') {
        final detected =
            HybridParserService.detectCardType(_parsedData!.rawText ?? '');
        if (detected != null && detected != _resolvedIdType) {
          debugPrint(
              '⚠️ Gap 6: Cashier selected "$_resolvedIdType" but OCR header '
              'keywords indicate "$detected" — correcting.');
          _originalIdType = _resolvedIdType;
          _resolvedIdType = detected;
          _typeWasCorrected = true;

          // The first parse used the wrong layout, so parse again as the
          // corrected type. The seal calibration is also type-specific.
          final bytes = await imageFile.readAsBytes();
          final image = img.decodeImage(bytes);
          if (image != null) {
            final sealResult = await SealPresenceDetector.checkSeal(
              imagePath: imageFile.path,
              imageWidth: image.width,
              imageHeight: image.height,
              beneficiaryType: _resolvedIdType,
            );
            _resolvedSealDetected = sealResult.sealDetected;
            _resolvedIdFormat = sealResult.sealDetected == true ? 'new' : 'old';
          }
          _parsedData = await _hybridParser.parseIDWithHybridApproach(
            imageFile: imageFile,
            idType: _resolvedIdType,
            idFormat: _resolvedIdFormat,
          );
          if (!_parsedData!.success) {
            _handleError(_parsedData!.errorMessage ??
                'Re-parsing as $_resolvedIdType failed');
            return;
          }
        }
      }

      // Done — show fields for user review
      setState(() {
        _currentStep = ProcessingStep.done;
        _progress = 1.0;
        _isProcessing = false;
      });

      _animationController.stop();
      _initializeControllers();

      // Gap 5: Warn the cashier when we had to skip Tesseract due to timeout.
      if (_isTimeoutFallback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'OCR took too long — showing reduced-confidence result. '
              'Please review each field carefully before confirming.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          ),
        );
      }

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
        shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.face_outlined, color: Color(0xFFE65100)),
            const SizedBox(width: 8),
            Text(
              'No Face Detected',
              style: GoogleFonts.sourceSerif4(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                color: AppDesignSystem.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'No ID photo was detected in the captured image.\n\n'
          'The card may not be fully in frame, or the photo area '
          'is obscured. Recapturing is strongly recommended.\n\n'
          'A non-ID image should not be used for verification.',
          style: AppDesignSystem.bodyMedium
              .copyWith(color: AppDesignSystem.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Continue Anyway',
              style: AppDesignSystem.bodyMedium
                  .copyWith(color: AppDesignSystem.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppDesignSystem.primaryButton,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Recapture'),
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
        shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.cardRadius),
        title: Text(
          'Select ID Type',
          style: GoogleFonts.sourceSerif4(
            fontWeight: FontWeight.w700,
            fontSize: 19,
            color: AppDesignSystem.textPrimary,
          ),
        ),
        content: Text(
          'The card type could not be detected automatically. '
          'Please select the correct type to continue.',
          style: AppDesignSystem.bodyMedium
              .copyWith(color: AppDesignSystem.textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(
              'Cancel',
              style: AppDesignSystem.bodyMedium
                  .copyWith(color: AppDesignSystem.textSecondary),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'senior'),
                style: AppDesignSystem.secondaryButton,
                child: const Text('Senior Citizen'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'pwd'),
                style: AppDesignSystem.primaryButton,
                child: const Text('PWD'),
              ),
            ],
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

    debugPrint('[TRACE] ProcessingScreen -> VerifyingScreen: '
        'idType=$_resolvedIdType idFormat=$_resolvedIdFormat '
        'sealDetected=$_resolvedSealDetected');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyingScreen(
          parsedData: updatedData,
          imagePath: widget.imagePath,
          idType: _resolvedIdType,
          idFormat: _resolvedIdFormat,
          sealDetected: _resolvedSealDetected,
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
        title: Text(
          'Processing ID',
          style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: AppDesignSystem.primaryBlue,
        foregroundColor: AppDesignSystem.textOnPrimary,
      ),
      body: Stack(
        children: [
          // Ledger-ruled texture — distinct from the guilloché motif
          // used on login/camera/review, since this screen is a
          // form/data-review moment rather than an ID-capture moment.
          const Positioned.fill(
            child: CustomPaint(painter: LedgerLinesPainter()),
          ),
          SafeArea(
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
        ],
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
    final stepLabels = {
      ProcessingStep.analyzing: 'ANALYZE',
      ProcessingStep.extracting: 'EXTRACT',
      ProcessingStep.done: 'DONE',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((step) {
        final isCompleted = step.index <= _currentStep.index;
        final isCurrent = step == _currentStep;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
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
                const SizedBox(height: 6),
                Text(
                  stepLabels[step]!,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 8,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? AppDesignSystem.primaryBlue
                        : AppDesignSystem.textTertiary,
                  ),
                ),
              ],
            ),
            if (step != steps.last)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Container(
                  width: 24,
                  height: 2,
                  color: isCompleted
                      ? AppDesignSystem.primaryBlue
                      : AppDesignSystem.borderLight,
                ),
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
                child: SizedBox(
                  height: AppDesignSystem.touchTargetPrimary,
                  child: OutlinedButton(
                    onPressed: _retake,
                    style: AppDesignSystem.secondaryButton.copyWith(
                      fixedSize: MaterialStateProperty.all(
                          Size.fromHeight(AppDesignSystem.touchTargetPrimary)),
                      // Default padding (32/18) is sized for one full-width
                      // button; halved here so two buttons can share a row
                      // without the label being squeezed into the icon's space.
                      padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    child: const Text('Retake Photo'),
                  ),
                ),
              ),
              SizedBox(width: AppDesignSystem.spaceSM),
              Expanded(
                child: SizedBox(
                  height: AppDesignSystem.touchTargetPrimary,
                  child: ElevatedButton(
                    onPressed: _processWithoutQualityCheck,
                    style: AppDesignSystem.primaryButton.copyWith(
                      fixedSize: MaterialStateProperty.all(
                          Size.fromHeight(AppDesignSystem.touchTargetPrimary)),
                      padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    child: const Text('Try Anyway'),
                  ),
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
        if (_typeWasCorrected) _buildTypeCorrectionBanner(),
        _buildReviewBanner(),
        SizedBox(height: AppDesignSystem.spaceMD),
        _buildDataFields(),
        SizedBox(height: AppDesignSystem.spaceMD),
        _buildActionButtons(),
      ],
    );
  }

  /// Gap 6: Shown when OCR header keywords contradict the cashier's manual
  /// type selection.  _resolvedIdType has already been corrected, so
  /// verification will use the right beneficiary_type.
  Widget _buildTypeCorrectionBanner() {
    final correctedLabel =
        _resolvedIdType == 'senior' ? 'Senior Citizen' : 'PWD';
    final originalLabel =
        _originalIdType == 'senior' ? 'Senior Citizen' : 'PWD';
    return Padding(
      padding: EdgeInsets.only(bottom: AppDesignSystem.spaceMD),
      child: AppNotice(
        type: AppNoticeType.warning,
        label: 'ID Type Auto-Corrected',
        message: 'OCR detected a $correctedLabel card '
            '(you selected $originalLabel). '
            'Verification will use the correct type.',
      ),
    );
  }

  Widget _buildReviewBanner() {
    return const AppNotice(
      type: AppNoticeType.info,
      label: 'Review Extracted Data',
      message: 'Please review and correct any errors before confirming.',
    );
  }

  Widget _buildDataFields() {
    final isPWD = _resolvedIdType == 'pwd';
    return Container(
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
                  style: GoogleFonts.sourceSerif4(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    color: AppDesignSystem.primaryBlue,
                  )),
            ],
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          Text('Review and correct if needed before confirming:',
              style: AppDesignSystem.bodyMedium
                  .copyWith(color: AppDesignSystem.textSecondary)),
          SizedBox(height: AppDesignSystem.spaceMD),
          _buildInfoRow('ID Type', isPWD ? 'PWD' : 'Senior Citizen'),
          SizedBox(height: AppDesignSystem.spaceSM),
          _buildEditableField('Full Name', 'fullName', Icons.person),
          SizedBox(height: AppDesignSystem.spaceSM),
          if (isPWD) ...[
            _buildEditableField('Type of Disability', 'disabilityType',
                Icons.accessible_forward),
            SizedBox(height: AppDesignSystem.spaceSM),
            _buildEditableField(
                'ID No.', 'controlNumber', Icons.confirmation_number,
                monospace: true),
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
                'Control Number', 'controlNumber', Icons.confirmation_number,
                monospace: true),
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
      {TextInputType keyboardType = TextInputType.text,
      bool monospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppDesignSystem.label),
        SizedBox(height: AppDesignSystem.spaceXXS),
        TextField(
          controller: _controllers[controllerKey],
          keyboardType: keyboardType,
          style: monospace
              ? GoogleFonts.ibmPlexMono(
                  fontSize: AppDesignSystem.bodyMedium.fontSize,
                  color: AppDesignSystem.bodyMedium.color,
                )
              : AppDesignSystem.bodyMedium,
          decoration: AppDesignSystem.inputDecoration(
              hintText: 'Enter $label', prefixIcon: icon),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    // Root cause (confirmed from AppDesignSystem): secondaryButton/
    // primaryButton use 32px horizontal padding + a 64dp minimumSize,
    // sized for a single full-width button. Split 1:2 across two
    // buttons in a row, that fixed padding eats most of the narrower
    // button's space, leaving no room for the label at this system's
    // accessibility-sized (18sp) text — that's what caused the
    // letter-by-letter wrap. Fix: keep the intended 64dp touch target
    // (don't shrink it — that's WCAG-motivated), just reduce padding
    // for this two-button context. FittedBox stays as cheap insurance
    // on top, not the actual fix.
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: AppDesignSystem.touchTargetPrimary,
            child: OutlinedButton(
              onPressed: _retake,
              style: AppDesignSystem.secondaryButton.copyWith(
                fixedSize: MaterialStateProperty.all(
                    Size.fromHeight(AppDesignSystem.touchTargetPrimary)),
                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.camera_alt, size: 18),
                    SizedBox(width: 8),
                    Text('Retake'),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: AppDesignSystem.spaceSM),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: AppDesignSystem.touchTargetPrimary,
            child: ElevatedButton(
              onPressed: _confirm,
              style: AppDesignSystem.primaryButton.copyWith(
                fixedSize: MaterialStateProperty.all(
                    Size.fromHeight(AppDesignSystem.touchTargetPrimary)),
                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, size: 18),
                    SizedBox(width: 8),
                    Text('Confirm'),
                  ],
                ),
              ),
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
