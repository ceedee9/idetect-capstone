import 'dart:io';

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/parser_service.dart';
import 'result_screen.dart';

class VerifyingScreen extends StatefulWidget {
  final ParsedIDData parsedData;
  final String imagePath;
  final String idType;
  final String
      idFormat; // 'old' or 'new' — available here, not yet sent to the API

  const VerifyingScreen({
    super.key,
    required this.parsedData,
    required this.imagePath,
    required this.idType,
    this.idFormat = 'old',
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 12),
                  _buildVerifyingBanner(),
                  const SizedBox(height: 12),
                  _buildIDPreviewCard(),
                  const SizedBox(height: 16),
                  _buildExtractedDetailsCard(),
                  const SizedBox(height: 16),
                  _buildVerifyButton(),
                  const SizedBox(height: 24),
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                    child: Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'VERIFYING ID',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyingBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF002E6B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A6FB3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _isVerifying
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Icon(Icons.manage_search, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHECKING DATABASE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isVerifying
                      ? 'Comparing ID against OSCA/PDAO records...'
                      : 'Verification starts when you tap the button below.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIDPreviewCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(widget.imagePath),
          width: 340,
          height: 214,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildExtractedDetailsCard() {
    final isPWD = widget.idType == 'pwd';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'EXTRACTED DETAILS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF002E6B),
              letterSpacing: 1.2,
            ),
          ),
          const Divider(height: 20, thickness: 2),
          _detailRow('NAME:', widget.parsedData.fullName ?? 'N/A'),
          const SizedBox(height: 10),
          if (isPWD) ...[
            _detailRow('TYPE OF DISABILITY:',
                widget.parsedData.disabilityType ?? 'N/A'),
            const SizedBox(height: 10),
            _detailRow(
              'ID NO:',
              widget.parsedData.controlNumber ??
                  widget.parsedData.idNumber ??
                  'N/A',
            ),
          ] else ...[
            _detailRow(
              'AGE:',
              widget.parsedData.age != null
                  ? '${widget.parsedData.age} Years Old'
                  : 'N/A',
            ),
            const SizedBox(height: 10),
            _detailRow('SEX:', widget.parsedData.sex ?? 'N/A'),
            const SizedBox(height: 10),
            _detailRow('DATE ISSUED:', widget.parsedData.dateIssued ?? 'N/A'),
            const SizedBox(height: 10),
            _detailRow('CONTROL ID:', widget.parsedData.controlNumber ?? 'N/A'),
          ],
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isVerifying ? null : _startVerification,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF002E6B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _isVerifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.verified_user),
          label: Text(
            _isVerifying ? 'Verifying...' : 'Verify',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
