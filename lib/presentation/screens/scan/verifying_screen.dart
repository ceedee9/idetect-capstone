import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_design_system.dart';
import '../../../services/api_service.dart';
import '../../../services/parser_service.dart';
import 'result_screen.dart';

class VerifyingScreen extends StatefulWidget {
  final ParsedIDData parsedData;
  final String imagePath;
  final String idType;
  final String idFormat;
  final bool? sealDetected;

  const VerifyingScreen({
    super.key,
    required this.parsedData,
    required this.imagePath,
    required this.idType,
    this.idFormat = 'old',
    this.sealDetected,
  });

  @override
  State<VerifyingScreen> createState() => _VerifyingScreenState();
}

class _VerifyingScreenState extends State<VerifyingScreen> {
  bool _isVerifying = false;
  String _statusText = 'Review the extracted details, then tap Verify.';

  Future<void> _startVerification() async {
    setState(() {
      _isVerifying = true;
      _statusText = 'Verifying with official records...';
    });

    final idNumber =
        (widget.parsedData.controlNumber?.trim().isNotEmpty == true)
            ? widget.parsedData.controlNumber!.trim()
            : (widget.parsedData.idNumber?.trim() ?? '');

    final beneficiaryType =
        widget.idType == 'senior' ? 'senior_citizen' : 'pwd';

    VerificationResult verificationResult;

    if (idNumber.isEmpty) {
      verificationResult = VerificationResult(
        status: VerificationStatus.manualReview,
        message: 'No ID number entered. Please verify manually.',
      );
    } else {
      verificationResult = await ApiService.verifyId(
        idNumber: idNumber,
        beneficiaryType: beneficiaryType,
        ocrConfidence: widget.parsedData.confidence,
        imagePath: widget.imagePath,
        manuallyEntered: false,
        extractedName: widget.parsedData.fullName,
        extractedDob: widget.parsedData.dateOfBirth,
        idFormat: widget.idFormat,
        sealDetected: widget.sealDetected,
      );
    }

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _statusText = verificationResult.message ?? 'Verification complete.';
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          parsedData: widget.parsedData,
          imagePath: widget.imagePath,
          idType: widget.idType,
          verificationResult: verificationResult,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Verify ID',
          style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: AppDesignSystem.primaryBlue,
        foregroundColor: AppDesignSystem.textOnPrimary,
      ),
      body: Stack(
        children: [
          // Captured ID, zoomed to fill the screen — the original
          // verifying-screen backdrop, kept behind the new card layout.
          Positioned.fill(
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppDesignSystem.spaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImagePreview(),
                  SizedBox(height: AppDesignSystem.spaceMD),
                  _buildVerifyingStatus(),
                  SizedBox(height: AppDesignSystem.spaceMD),
                  _buildExtractedDetailsCard(),
                  SizedBox(height: AppDesignSystem.spaceLG),
                  _buildVerifyButton(),
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

  Widget _buildVerifyingStatus() {
    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceSM),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
        border: Border.all(
          color: AppDesignSystem.primaryBlue.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _isVerifying
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: AppDesignSystem.primaryBlue,
                    strokeWidth: 3,
                  ),
                )
              : Icon(Icons.manage_search_rounded,
                  color: AppDesignSystem.primaryBlue, size: 36),
          SizedBox(width: AppDesignSystem.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isVerifying ? 'CHECKING DATABASE' : 'READY TO VERIFY',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppDesignSystem.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusText,
                  style: AppDesignSystem.bodyMedium
                      .copyWith(color: AppDesignSystem.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedDetailsCard() {
    final isPWD = widget.idType == 'pwd';

    return Container(
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined,
                  size: AppDesignSystem.iconMD,
                  color: AppDesignSystem.primaryBlue),
              SizedBox(width: AppDesignSystem.spaceXS),
              Text(
                'Extracted Details',
                style: GoogleFonts.sourceSerif4(
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  color: AppDesignSystem.primaryBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          const Divider(height: 1, color: AppDesignSystem.borderLight),
          SizedBox(height: AppDesignSystem.spaceSM),
          _detailRow('Name', widget.parsedData.fullName ?? 'N/A'),
          if (isPWD) ...[
            SizedBox(height: AppDesignSystem.spaceXS),
            _detailRow('Type of Disability',
                widget.parsedData.disabilityType ?? 'N/A'),
            SizedBox(height: AppDesignSystem.spaceXS),
            _detailRow(
              'ID No.',
              widget.parsedData.controlNumber ??
                  widget.parsedData.idNumber ??
                  'N/A',
              monospace: true,
            ),
          ] else ...[
            SizedBox(height: AppDesignSystem.spaceXS),
            _detailRow(
              'Age',
              widget.parsedData.age != null
                  ? '${widget.parsedData.age} Years Old'
                  : 'N/A',
            ),
            SizedBox(height: AppDesignSystem.spaceXS),
            _detailRow('Sex', widget.parsedData.sex ?? 'N/A'),
            SizedBox(height: AppDesignSystem.spaceXS),
            _detailRow('Date Issued', widget.parsedData.dateIssued ?? 'N/A'),
            SizedBox(height: AppDesignSystem.spaceXS),
            _detailRow('Control ID', widget.parsedData.controlNumber ?? 'N/A',
                monospace: true),
          ],
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      height: AppDesignSystem.touchTargetPrimary,
      child: ElevatedButton.icon(
        onPressed: _isVerifying ? null : _startVerification,
        style: AppDesignSystem.primaryButton,
        icon: _isVerifying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.verified_user_rounded),
        label: Text(_isVerifying ? 'Verifying...' : 'Verify'),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool monospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: AppDesignSystem.label),
        ),
        Expanded(
          child: Text(
            value,
            style: monospace
                ? GoogleFonts.ibmPlexMono(
                    fontSize: AppDesignSystem.bodyMedium.fontSize,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.textPrimary,
                  )
                : AppDesignSystem.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
