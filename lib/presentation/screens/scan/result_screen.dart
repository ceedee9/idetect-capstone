// =============================================================================
// FILE: lib/presentation/screens/scan/result_screen.dart
// PURPOSE: Display extracted ID data and verify with database
// FEATURES: Edit mode, validation, confidence display, database verification
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_design_system.dart';
import '../../../services/parser_service.dart';

/// Result screen showing extracted ID information
///
/// Features:
/// - Display all extracted fields
/// - Visual hierarchy (important fields larger)
/// - Confidence score badge
/// - Edit mode for manual corrections
/// - Data validation
/// - Database verification button
class ResultScreen extends StatefulWidget {
  final ParsedIDData parsedData;
  final String imagePath;

  const ResultScreen({
    super.key,
    required this.parsedData,
    required this.imagePath,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // Edit mode state
  bool _isEditMode = false;
  bool _isVerifying = false;

  // Text editing controllers
  late TextEditingController _nameController;
  late TextEditingController _idNumberController;
  late TextEditingController _ageController;
  late TextEditingController _sexController;
  late TextEditingController _dateIssuedController;
  late TextEditingController _controlNumberController;

  // Validation errors
  final Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _ageController.dispose();
    _sexController.dispose();
    _dateIssuedController.dispose();
    _controlNumberController.dispose();
    super.dispose();
  }

  /// Initialize text controllers with parsed data
  void _initializeControllers() {
    _nameController = TextEditingController(
      text: widget.parsedData.fullName ?? '',
    );
    _idNumberController = TextEditingController(
      text: widget.parsedData.idNumber ?? '',
    );
    _ageController = TextEditingController(
      text: widget.parsedData.age?.toString() ?? '',
    );
    _sexController = TextEditingController(
      text: widget.parsedData.sex ?? '',
    );
    _dateIssuedController = TextEditingController(
      text: widget.parsedData.dateIssued ?? '',
    );
    _controlNumberController = TextEditingController(
      text: widget.parsedData.controlNumber ?? '',
    );
  }

  // ===========================================================================
  // ACTIONS
  // ===========================================================================

  /// Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      if (_isEditMode) {
        // Exiting edit mode - validate
        if (_validateAllFields()) {
          _isEditMode = false;
          _errors.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Changes saved'),
              backgroundColor: AppDesignSystem.statusValid,
            ),
          );
        }
      } else {
        // Entering edit mode
        _isEditMode = true;
      }
    });
  }

  /// Verify with database
  Future<void> _verifyWithDatabase() async {
    // Validate before verification
    if (!_validateAllFields()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fix all errors before verification'),
          backgroundColor: AppDesignSystem.statusInvalid,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    // Simulate database verification (replace with actual service call)
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isVerifying = false);

    // TODO: Replace with actual verification logic
    // For now, show success dialog
    _showVerificationResultDialog(
      isValid: true,
      message: 'ID verified successfully in database',
    );
  }

  /// Show verification result dialog
  void _showVerificationResultDialog({
    required bool isValid,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isValid ? Icons.check_circle : Icons.cancel,
              color: isValid
                  ? AppDesignSystem.statusValid
                  : AppDesignSystem.statusInvalid,
              size: AppDesignSystem.iconLG,
            ),
            SizedBox(width: AppDesignSystem.spaceXS),
            Text(
              isValid ? 'Verified' : 'Not Found',
              style: TextStyle(
                color: isValid
                    ? AppDesignSystem.statusValid
                    : AppDesignSystem.statusInvalid,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          if (!isValid)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isEditMode = true);
              },
              child: const Text('Edit'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (isValid) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            style: AppDesignSystem.primaryButton,
            child: Text(isValid ? 'Done' : 'OK'),
          ),
        ],
      ),
    );
  }

  /// Retake photo
  void _retake() {
    Navigator.pop(context);
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  /// Validate all fields
  bool _validateAllFields() {
    bool isValid = true;
    _errors.clear();

    // Validate name
    if (_nameController.text.trim().isEmpty) {
      _errors['name'] = 'Name is required';
      isValid = false;
    } else if (_nameController.text.trim().length < 3) {
      _errors['name'] = 'Name too short';
      isValid = false;
    }

    // Validate ID number
    if (_idNumberController.text.trim().isEmpty) {
      _errors['idNumber'] = 'ID number is required';
      isValid = false;
    }

    // Validate age
    final age = int.tryParse(_ageController.text.trim());
    if (age == null) {
      _errors['age'] = 'Invalid age';
      isValid = false;
    } else if (age < 0 || age > 150) {
      _errors['age'] = 'Age must be between 0-150';
      isValid = false;
    }

    // Validate sex
    if (_sexController.text.trim().isEmpty) {
      _errors['sex'] = 'Sex is required';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  // ===========================================================================
  // BUILD UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        title: const Text('ID Information'),
        centerTitle: true,
        backgroundColor: AppDesignSystem.primaryBlue,
        foregroundColor: AppDesignSystem.textOnPrimary,
        actions: [
          // Edit button
          IconButton(
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
            onPressed: _toggleEditMode,
            tooltip: _isEditMode ? 'Save Changes' : 'Edit',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDesignSystem.spaceMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ID image thumbnail
                    _buildImageThumbnail(),

                    SizedBox(height: AppDesignSystem.spaceMD),

                    // Confidence badge
                    _buildConfidenceBadge(),

                    SizedBox(height: AppDesignSystem.spaceMD),

                    // ID Type card (most prominent)
                    _buildIDTypeCard(),

                    SizedBox(height: AppDesignSystem.spaceMD),

                    // Main information card
                    _buildMainInfoCard(),

                    SizedBox(height: AppDesignSystem.spaceMD),

                    // Additional details card
                    _buildAdditionalDetailsCard(),
                  ],
                ),
              ),
            ),

            // Bottom action area
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  /// Build image thumbnail
  Widget _buildImageThumbnail() {
    return GestureDetector(
      onTap: () => _showFullImage(),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: AppDesignSystem.cardRadius,
          boxShadow: AppDesignSystem.shadowSM,
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: AppDesignSystem.cardRadius,
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            // Tap to enlarge overlay
            Positioned(
              bottom: AppDesignSystem.spaceXS,
              right: AppDesignSystem.spaceXS,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.spaceXS,
                  vertical: AppDesignSystem.spaceXXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.zoom_in,
                      size: AppDesignSystem.iconSM,
                      color: AppDesignSystem.textOnDark,
                    ),
                    SizedBox(width: AppDesignSystem.spaceXXS),
                    Text(
                      'Tap to enlarge',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: AppDesignSystem.textOnDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build confidence badge
  Widget _buildConfidenceBadge() {
    final confidence = widget.parsedData.confidence;
    final percentage = (confidence * 100).toInt();

    Color badgeColor;
    String label;
    IconData icon;

    if (confidence >= 0.9) {
      badgeColor = AppDesignSystem.statusValid;
      label = 'EXCELLENT';
      icon = Icons.verified;
    } else if (confidence >= 0.8) {
      badgeColor = AppDesignSystem.statusValid;
      label = 'VERY GOOD';
      icon = Icons.check_circle;
    } else if (confidence >= 0.7) {
      badgeColor = Colors.orange;
      label = 'GOOD';
      icon = Icons.check_circle_outline;
    } else {
      badgeColor = AppDesignSystem.statusInvalid;
      label = 'LOW CONFIDENCE';
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: AppDesignSystem.cardRadius,
        border: Border.all(
          color: badgeColor,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: badgeColor, size: AppDesignSystem.iconMD),
          SizedBox(width: AppDesignSystem.spaceXS),
          Text(
            'Confidence: $percentage% • $label',
            style: AppDesignSystem.bodyLarge.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build ID type card (most prominent)
  Widget _buildIDTypeCard() {
    final idType = widget.parsedData.idType;
    String typeLabel;
    Color typeColor;
    IconData typeIcon;

    switch (idType) {
      case IDType.seniorCitizen:
        typeLabel = 'SENIOR CITIZEN ID';
        typeColor = AppDesignSystem.primaryBlue;
        typeIcon = Icons.elderly;
        break;
      case IDType.pwd:
        typeLabel = 'PWD ID';
        typeColor = AppDesignSystem.secondaryBlue;
        typeIcon = Icons.accessible;
        break;
      default:
        typeLabel = 'UNKNOWN ID TYPE';
        typeColor = AppDesignSystem.textSecondary;
        typeIcon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [typeColor, typeColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowLG,
      ),
      child: Column(
        children: [
          Icon(
            typeIcon,
            size: 64,
            color: AppDesignSystem.textOnPrimary,
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          Text(
            typeLabel,
            style: AppDesignSystem.heading2.copyWith(
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build main information card (Name, ID Number)
  Widget _buildMainInfoCard() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceLG),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Primary Information',
            style: AppDesignSystem.heading4.copyWith(
              color: AppDesignSystem.primaryBlue,
            ),
          ),

          SizedBox(height: AppDesignSystem.spaceMD),

          // Full Name (most important - larger)
          _buildFieldDisplay(
            label: 'FULL NAME',
            controller: _nameController,
            icon: Icons.person,
            isLargeText: true,
            error: _errors['name'],
            confidence: widget.parsedData.nameConfidence,
          ),

          SizedBox(height: AppDesignSystem.spaceMD),

          // ID Number (second most important)
          _buildFieldDisplay(
            label: 'ID NUMBER',
            controller: _idNumberController,
            icon: Icons.badge,
            isLargeText: true,
            error: _errors['idNumber'],
            confidence: widget.parsedData.idNumberConfidence,
          ),
        ],
      ),
    );
  }

  /// Build additional details card
  Widget _buildAdditionalDetailsCard() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceLG),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Additional Details',
            style: AppDesignSystem.heading4.copyWith(
              color: AppDesignSystem.primaryBlue,
            ),
          ),

          SizedBox(height: AppDesignSystem.spaceMD),

          // Age and Sex in a row
          Row(
            children: [
              Expanded(
                child: _buildFieldDisplay(
                  label: 'AGE',
                  controller: _ageController,
                  icon: Icons.cake,
                  keyboardType: TextInputType.number,
                  error: _errors['age'],
                  confidence: widget.parsedData.ageConfidence,
                ),
              ),
              SizedBox(width: AppDesignSystem.spaceMD),
              Expanded(
                child: _buildFieldDisplay(
                  label: 'SEX',
                  controller: _sexController,
                  icon: Icons.wc,
                  error: _errors['sex'],
                  confidence: widget.parsedData.sexConfidence,
                ),
              ),
            ],
          ),

          SizedBox(height: AppDesignSystem.spaceMD),

          // Date Issued
          _buildFieldDisplay(
            label: 'DATE ISSUED',
            controller: _dateIssuedController,
            icon: Icons.calendar_today,
            confidence: widget.parsedData.dateIssuedConfidence,
          ),

          SizedBox(height: AppDesignSystem.spaceMD),

          // Control Number
          _buildFieldDisplay(
            label: 'CONTROL NUMBER',
            controller: _controlNumberController,
            icon: Icons.confirmation_number,
            confidence: widget.parsedData.controlNumberConfidence,
          ),
        ],
      ),
    );
  }

  /// Build field display (read-only or editable)
  Widget _buildFieldDisplay({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isLargeText = false,
    String? error,
    double confidence = 0.0,
  }) {
    // Determine text style based on importance
    final textStyle = isLargeText
        ? AppDesignSystem.heading4.copyWith(
            color: AppDesignSystem.textPrimary,
            fontWeight: FontWeight.bold,
          )
        : AppDesignSystem.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          );

    final labelStyle = isLargeText
        ? AppDesignSystem.bodyMedium.copyWith(
            color: AppDesignSystem.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          )
        : AppDesignSystem.bodySmall.copyWith(
            color: AppDesignSystem.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with confidence badge
        Row(
          children: [
            Icon(
              icon,
              size:
                  isLargeText ? AppDesignSystem.iconMD : AppDesignSystem.iconSM,
              color: AppDesignSystem.primaryBlue,
            ),
            SizedBox(width: AppDesignSystem.spaceXXS),
            Text(label, style: labelStyle),
            Spacer(),
            // Confidence badge
            if (confidence > 0) _buildFieldConfidenceBadge(confidence),
          ],
        ),

        SizedBox(height: AppDesignSystem.spaceXXS),

        // Value (editable or read-only)
        if (_isEditMode)
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: textStyle,
            decoration: InputDecoration(
              hintText: 'Enter $label',
              errorText: error,
              filled: true,
              fillColor: AppDesignSystem.backgroundLightBlue,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                borderSide: BorderSide(
                  color: AppDesignSystem.primaryBlue,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                borderSide: BorderSide(
                  color: AppDesignSystem.statusInvalid,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.spaceSM,
                vertical: AppDesignSystem.spaceSM,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spaceSM,
              vertical: isLargeText
                  ? AppDesignSystem.spaceSM
                  : AppDesignSystem.spaceXS,
            ),
            decoration: BoxDecoration(
              color: AppDesignSystem.backgroundLight,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
            ),
            child: Text(
              controller.text.isEmpty ? 'N/A' : controller.text,
              style: controller.text.isEmpty
                  ? textStyle.copyWith(
                      color: AppDesignSystem.textTertiary,
                      fontStyle: FontStyle.italic,
                    )
                  : textStyle,
            ),
          ),
      ],
    );
  }

  /// Build field confidence badge (per-field)
  Widget _buildFieldConfidenceBadge(double confidence) {
    final percentage = (confidence * 100).toInt();

    Color badgeColor;
    String label;

    if (confidence >= 0.9) {
      badgeColor = AppDesignSystem.statusValid;
      label = 'High';
    } else if (confidence >= 0.7) {
      badgeColor = Colors.orange;
      label = 'Medium';
    } else if (confidence > 0) {
      badgeColor = AppDesignSystem.statusInvalid;
      label = 'Low';
    } else {
      badgeColor = AppDesignSystem.textTertiary;
      label = 'N/A';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spaceXS,
        vertical: AppDesignSystem.spaceXXS,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        border: Border.all(color: badgeColor, width: 1),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confidence >= 0.9
                ? Icons.check_circle
                : confidence >= 0.7
                    ? Icons.info
                    : Icons.warning_amber_rounded,
            size: 12,
            color: badgeColor,
          ),
          SizedBox(width: 4),
          Text(
            '$percentage% ($label)',
            style: AppDesignSystem.bodySmall.copyWith(
              fontSize: 11,
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom action buttons
  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Verify with Database button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyWithDatabase,
                style: AppDesignSystem.primaryButton.copyWith(
                  minimumSize: MaterialStateProperty.all(
                    const Size(double.infinity, 56),
                  ),
                ),
                child: _isVerifying
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppDesignSystem.textOnPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: AppDesignSystem.spaceSM),
                          const Text('Verifying...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user),
                          SizedBox(width: AppDesignSystem.spaceXS),
                          const Text('Verify with Database'),
                        ],
                      ),
              ),
            ),

            SizedBox(height: AppDesignSystem.spaceXS),

            // Retake photo button
            TextButton(
              onPressed: _retake,
              style: AppDesignSystem.textButton,
              child: const Text('Retake Photo'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show full image dialog
  void _showFullImage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Full image
            Center(
              child: InteractiveViewer(
                child: Image.file(File(widget.imagePath)),
              ),
            ),
            // Close button
            Positioned(
              top: AppDesignSystem.spaceMD,
              right: AppDesignSystem.spaceMD,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                color: AppDesignSystem.textOnDark,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
