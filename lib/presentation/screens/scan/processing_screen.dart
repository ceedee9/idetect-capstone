// =============================================================================
// FILE: lib/presentation/screens/scan/processing_screen.dart
// PURPOSE: Process captured ID image with OCR and display results
// FEATURES: Step-by-step progress, OCR processing, data extraction, editing
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_design_system.dart';
import '../../../services/enhanced_ocr_service.dart'; // Enhanced OCR with Tesseract + ML Kit
import '../../../services/hybrid_parser_service.dart'; // NEW: Hybrid parser with layout-based extraction
import '../../../services/parser_service.dart';
import 'result_screen.dart';

/// Processing screen that handles OCR and ID data extraction
///
/// Steps:
/// 1. Analyze image quality
/// 2. Extract text with OCR
/// 3. Parse ID data
/// 4. Display results with confidence scores
/// 5. Allow editing and confirmation
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
  final EnhancedOCRService _ocrService = EnhancedOCRService(); // Enhanced OCR
  final HybridParserService _hybridParser =
      HybridParserService(); // NEW: Hybrid parser
  final ParserService _parserService = ParserService(); // Fallback

  // Processing state
  ProcessingStep _currentStep = ProcessingStep.analyzing;
  bool _isProcessing = true;
  double _progress = 0.0;

  // Results
  EnhancedOCRResult? _ocrResult;
  ParsedIDData? _parsedData;
  String? _errorMessage;
  String? _ocrEngine; // Track which engine was used

  // Animation controller for progress indicator
  late AnimationController _animationController;

  // Text editing controllers for manual correction
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppDesignSystem.animationNormal,
    )..repeat();

    // Start processing
    _startProcessing();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ocrService.dispose();
    _hybridParser.dispose(); // NEW: Dispose hybrid parser
    // Dispose all text controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ===========================================================================
  // PROCESSING PIPELINE
  // ===========================================================================

  /// Start the OCR and parsing pipeline
  Future<void> _startProcessing() async {
    try {
      debugPrint('=== PROCESSING START ===');
      debugPrint('Image path: ${widget.imagePath}');
      debugPrint('ID type: ${widget.idType}');

      // Verify image file exists
      final imageFile = File(widget.imagePath);
      if (!await imageFile.exists()) {
        _handleError('Image file not found: ${widget.imagePath}');
        return;
      }
      debugPrint('✅ Image file exists (${await imageFile.length()} bytes)');

      // Step 1: Analyzing image quality
      setState(() {
        _currentStep = ProcessingStep.analyzing;
        _progress = 0.25;
      });
      await Future.delayed(const Duration(milliseconds: 800));

      // Step 2 & 3: HYBRID EXTRACTION (Layout-based + Fuzzy fallback)
      setState(() {
        _currentStep = ProcessingStep.extracting;
        _progress = 0.50;
      });

      debugPrint('🔄 Starting HYBRID OCR + Parsing...');
      debugPrint('💡 Using layout-based extraction with fuzzy fallback');

      // NEW: Use hybrid parser (combines OCR + layout extraction + fuzzy)
      try {
        _parsedData = await _hybridParser.parseIDWithHybridApproach(
          imageFile: imageFile,
          idType: widget.idType,
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
        debugPrint('❌ Hybrid parsing failed: ${_parsedData!.errorMessage}');
        _handleError(_parsedData!.errorMessage ?? 'Hybrid parsing failed');
        return;
      }

      debugPrint('✅ Hybrid parsing success');
      debugPrint('📊 Extraction method: ${_parsedData!.extractionMethod}');
      debugPrint('🎯 Template matched: ${_parsedData!.templateMatched}');
      debugPrint(
          '📈 Overall confidence: ${(_parsedData!.confidence * 100).toInt()}%');

      // Set OCR engine info for display
      _ocrEngine = 'ML Kit (with ${_parsedData!.extractionMethod})';

      // Step 4: Finalizing
      setState(() {
        _currentStep = ProcessingStep.parsing;
        _progress = 0.90;
      });
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 4: Done!
      setState(() {
        _currentStep = ProcessingStep.done;
        _progress = 1.0;
        _isProcessing = false;
      });

      _animationController.stop();

      // Initialize text controllers with extracted data
      _initializeControllers();

      debugPrint('=== PROCESSING COMPLETE ===');
    } catch (e, stackTrace) {
      debugPrint('❌ FATAL ERROR: $e');
      debugPrint('Stack trace: $stackTrace');
      _handleError('Processing error: $e');
    }
  }

  /// Initialize text editing controllers with extracted data
  void _initializeControllers() {
    _controllers['fullName'] = TextEditingController(
      text: _parsedData?.fullName ?? '',
    );
    _controllers['age'] = TextEditingController(
      text: _parsedData?.age?.toString() ?? '',
    );
    _controllers['sex'] = TextEditingController(
      text: _parsedData?.sex ?? '',
    );
    _controllers['dateIssued'] = TextEditingController(
      text: _parsedData?.dateIssued ?? '',
    );
    _controllers['controlNumber'] = TextEditingController(
      text: _parsedData?.controlNumber ?? '',
    );
  }

  /// Handle processing errors
  void _handleError(String message) {
    setState(() {
      _errorMessage = message;
      _isProcessing = false;
      _currentStep = ProcessingStep.error;
    });
    _animationController.stop();
  }

  // ===========================================================================
  // UI ACTIONS
  // ===========================================================================

  /// Retake photo
  void _retake() {
    // Pop processing screen to go back to camera
    Navigator.of(context).pop();
  }

  /// Process without quality check when user wants to force it
  Future<void> _processWithoutQualityCheck() async {
    try {
      setState(() {
        _errorMessage = null;
        _isProcessing = true;
        _currentStep = ProcessingStep.extracting;
        _progress = 0.50;
      });

      final imageFile = File(widget.imagePath);

      // Force process - Enhanced OCR doesn't have quality check bypass
      // So we just call the standard method
      _ocrResult = await _ocrService.processIDImage(
        imageFile: imageFile,
        idType: widget.idType,
      );

      if (!_ocrResult!.success) {
        _handleError(
            'Still failed to extract text. Image quality may be too poor.');
        return;
      }

      _ocrEngine = _ocrResult!.engine;

      // Parse the data
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

      // Done!
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

  /// Confirm and proceed to result screen
  void _confirm() {
    // Create updated parsed data with edited values
    final updatedData = ParsedIDData(
      success: true,
      idType: _parsedData?.idType,
      idNumber: _controllers['controlNumber']?.text, // Use control number as ID
      fullName: _controllers['fullName']?.text,
      age: int.tryParse(_controllers['age']?.text ?? ''),
      sex: _controllers['sex']?.text,
      dateIssued: _controllers['dateIssued']?.text,
      controlNumber: _controllers['controlNumber']?.text,
      confidence: _parsedData?.confidence ?? 0.0,
      rawText: _ocrResult?.rawText ?? '',
    );

    // Navigate to result screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          parsedData: updatedData,
          imagePath: widget.imagePath,
          idType: widget.idType,
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD UI
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
              // Captured image preview
              _buildImagePreview(),

              SizedBox(height: AppDesignSystem.spaceMD),

              // Processing status or results
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

  /// Build captured image preview
  Widget _buildImagePreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: ClipRRect(
        borderRadius: AppDesignSystem.cardRadius,
        child: Image.file(
          File(widget.imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// Build processing status indicator
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
          // Animated progress indicator
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 6,
              backgroundColor: AppDesignSystem.backgroundLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppDesignSystem.primaryBlue,
              ),
            ),
          ),

          SizedBox(height: AppDesignSystem.spaceMD),

          // Progress percentage
          Text(
            '${(_progress * 100).toInt()}%',
            style: AppDesignSystem.heading3.copyWith(
              color: AppDesignSystem.primaryBlue,
            ),
          ),

          SizedBox(height: AppDesignSystem.spaceSM),

          // Current step description
          Text(
            _getStepMessage(_currentStep),
            style: AppDesignSystem.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: AppDesignSystem.spaceXS),

          Text(
            _getStepDescription(_currentStep),
            style: AppDesignSystem.bodyMedium.copyWith(
              color: AppDesignSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: AppDesignSystem.spaceLG),

          // Step indicators
          _buildStepIndicators(),
        ],
      ),
    );
  }

  /// Build step indicators
  Widget _buildStepIndicators() {
    final steps = [
      ProcessingStep.analyzing,
      ProcessingStep.extracting,
      ProcessingStep.parsing,
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
                  ? Icon(
                      Icons.check,
                      size: AppDesignSystem.iconSM,
                      color: AppDesignSystem.textOnPrimary,
                    )
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

  /// Build error view
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
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppDesignSystem.statusInvalid,
          ),
          SizedBox(height: AppDesignSystem.spaceMD),
          Text(
            'Processing Failed',
            style: AppDesignSystem.heading3.copyWith(
              color: AppDesignSystem.statusInvalid,
            ),
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          Text(
            _errorMessage ?? 'An unknown error occurred',
            style: AppDesignSystem.bodyMedium.copyWith(
              color: AppDesignSystem.textSecondary,
            ),
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

  /// Build results view with extracted data
  Widget _buildResultsView() {
    final confidence = _parsedData?.confidence ?? 0.0;
    final isLowConfidence = confidence < 0.7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Confidence indicator
        _buildConfidenceCard(confidence),

        SizedBox(height: AppDesignSystem.spaceMD),

        // Low confidence warning
        if (isLowConfidence) _buildLowConfidenceWarning(),

        if (isLowConfidence) SizedBox(height: AppDesignSystem.spaceMD),

        // Extracted data fields (editable)
        _buildDataFields(),

        SizedBox(height: AppDesignSystem.spaceMD),

        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  /// Build confidence score card
  Widget _buildConfidenceCard(double confidence) {
    final percentage = (confidence * 100).toInt();
    Color confidenceColor;

    if (confidence >= 0.9) {
      confidenceColor = AppDesignSystem.statusValid;
    } else if (confidence >= 0.7) {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = AppDesignSystem.statusInvalid;
    }

    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: Row(
        children: [
          // Confidence circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: confidenceColor.withOpacity(0.1),
              border: Border.all(
                color: confidenceColor,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                '$percentage%',
                style: AppDesignSystem.bodyLarge.copyWith(
                  color: confidenceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          SizedBox(width: AppDesignSystem.spaceMD),

          // Confidence description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confidence Score',
                  style: AppDesignSystem.bodyMedium.copyWith(
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
                SizedBox(height: AppDesignSystem.spaceXXS),
                Text(
                  _getConfidenceLabel(confidence),
                  style: AppDesignSystem.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: confidenceColor,
                  ),
                ),
                // Show OCR engine used
                if (_ocrEngine != null)
                  Text(
                    'Engine: $_ocrEngine',
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: AppDesignSystem.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          // Status icon
          Icon(
            _getConfidenceIcon(confidence),
            color: confidenceColor,
            size: AppDesignSystem.iconLG,
          ),
        ],
      ),
    );
  }

  /// Build low confidence warning
  Widget _buildLowConfidenceWarning() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: AppDesignSystem.cardRadius,
        border: Border.all(
          color: Colors.orange,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: AppDesignSystem.iconLG,
          ),
          SizedBox(width: AppDesignSystem.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low Confidence',
                  style: AppDesignSystem.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                SizedBox(height: AppDesignSystem.spaceXXS),
                Text(
                  'Please verify the data below carefully. Consider retaking the photo for better accuracy.',
                  style: AppDesignSystem.bodyMedium.copyWith(
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build editable data fields
  Widget _buildDataFields() {
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
          // Header
          Row(
            children: [
              Icon(
                Icons.edit,
                size: AppDesignSystem.iconMD,
                color: AppDesignSystem.primaryBlue,
              ),
              SizedBox(width: AppDesignSystem.spaceXS),
              Text(
                'Extracted Data',
                style: AppDesignSystem.heading4.copyWith(
                  color: AppDesignSystem.primaryBlue,
                ),
              ),
            ],
          ),

          SizedBox(height: AppDesignSystem.spaceSM),

          Text(
            'Review and edit if needed:',
            style: AppDesignSystem.bodyMedium.copyWith(
              color: AppDesignSystem.textSecondary,
            ),
          ),

          SizedBox(height: AppDesignSystem.spaceMD),

          // ID Type
          _buildInfoRow(
            'ID Type',
            _parsedData?.idType?.name.toUpperCase() ?? 'Unknown',
            isEditable: false,
          ),

          SizedBox(height: AppDesignSystem.spaceSM),

          // Full Name (editable)
          _buildEditableField(
            'Full Name',
            'fullName',
            Icons.person,
          ),

          SizedBox(height: AppDesignSystem.spaceSM),

          // Age and Sex in a row
          Row(
            children: [
              Expanded(
                child: _buildEditableField(
                  'Age',
                  'age',
                  Icons.cake,
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: AppDesignSystem.spaceSM),
              Expanded(
                child: _buildEditableField(
                  'Sex',
                  'sex',
                  Icons.wc,
                ),
              ),
            ],
          ),

          SizedBox(height: AppDesignSystem.spaceSM),

          // Date Issued (editable)
          _buildEditableField(
            'Date Issued',
            'dateIssued',
            Icons.calendar_today,
          ),

          SizedBox(height: AppDesignSystem.spaceSM),

          // Control Number (editable)
          _buildEditableField(
            'Control Number',
            'controlNumber',
            Icons.confirmation_number,
          ),
        ],
      ),
    );
  }

  /// Build non-editable info row
  Widget _buildInfoRow(String label, String value, {bool isEditable = false}) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppDesignSystem.bodyMedium.copyWith(
              color: AppDesignSystem.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppDesignSystem.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Build editable text field
  Widget _buildEditableField(
    String label,
    String controllerKey,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppDesignSystem.label,
        ),
        SizedBox(height: AppDesignSystem.spaceXXS),
        TextField(
          controller: _controllers[controllerKey],
          keyboardType: keyboardType,
          style: AppDesignSystem.bodyMedium,
          decoration: AppDesignSystem.inputDecoration(
            hintText: 'Enter $label',
            prefixIcon: icon,
          ),
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Retake button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _retake,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF002E6B), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.camera_alt, color: Color(0xFF002E6B)),
            label: const Text(
              'Retake',
              style: TextStyle(
                color: Color(0xFF002E6B),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Confirm button
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002E6B),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text(
              'Confirm',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  String _getStepMessage(ProcessingStep step) {
    switch (step) {
      case ProcessingStep.analyzing:
        return 'Analyzing image quality...';
      case ProcessingStep.extracting:
        return 'Extracting text...';
      case ProcessingStep.parsing:
        return 'Parsing ID data...';
      case ProcessingStep.done:
        return 'Done!';
      case ProcessingStep.error:
        return 'Error';
    }
  }

  String _getStepDescription(ProcessingStep step) {
    switch (step) {
      case ProcessingStep.analyzing:
        return 'Checking brightness, sharpness, and resolution';
      case ProcessingStep.extracting:
        return 'Using AI to read text from the image';
      case ProcessingStep.parsing:
        return 'Identifying name, ID number, and other details';
      case ProcessingStep.done:
        return 'ID information extracted successfully!';
      case ProcessingStep.error:
        return '';
    }
  }

  String _getConfidenceLabel(double confidence) {
    if (confidence >= 0.9) return 'Excellent';
    if (confidence >= 0.8) return 'Very Good';
    if (confidence >= 0.7) return 'Good';
    if (confidence >= 0.6) return 'Fair';
    return 'Poor';
  }

  IconData _getConfidenceIcon(double confidence) {
    if (confidence >= 0.9) return Icons.check_circle;
    if (confidence >= 0.7) return Icons.check_circle_outline;
    return Icons.warning_amber_rounded;
  }
}

// =============================================================================
// ENUMS
// =============================================================================

/// Processing steps
enum ProcessingStep {
  analyzing,
  extracting,
  parsing,
  done,
  error,
}
