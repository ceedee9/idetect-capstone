import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/datasources/local/local_database.dart';
import '../../../services/api_service.dart';
import '../../../services/parser_service.dart';
import '../../../services/fraud_flag_sync_service.dart';

class ResultScreen extends StatefulWidget {
  final ParsedIDData parsedData;
  final String imagePath;
  final String idType;
  final VerificationResult? verificationResult;

  const ResultScreen({
    super.key,
    required this.parsedData,
    required this.imagePath,
    required this.idType,
    this.verificationResult,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaving = false;
  final TextEditingController _flagNotesController = TextEditingController();

  VerificationStatus get _status =>
      widget.verificationResult?.status ?? VerificationStatus.manualReview;

  bool get _canFlag =>
      _status == VerificationStatus.invalid ||
      _status == VerificationStatus.suspicious;

  @override
  void dispose() {
    _flagNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveToDatabase({required bool flagged}) async {
    setState(() => _isSaving = true);

    try {
      final database = LocalDatabase();
      final idNumber =
          widget.parsedData.controlNumber?.trim().isNotEmpty == true
              ? widget.parsedData.controlNumber!.trim()
              : (widget.parsedData.idNumber ?? '');

      String? flagReferenceNumber;
      bool isQueued = false;

      if (flagged) {
        // REQ-2.6.5: Prompt for beneficiary type when INVALID
        String? beneficiaryType;
        if (_status == VerificationStatus.invalid) {
          beneficiaryType = await _promptBeneficiaryType();
          if (beneficiaryType == null) {
            // User cancelled the dialog
            setState(() => _isSaving = false);
            return;
          }
        } else {
          // Use detected type for suspicious/other statuses
          beneficiaryType =
              widget.idType == 'senior' ? 'senior_citizen' : 'pwd';
        }

        final verificationLogId = widget.verificationResult?.verificationId;
        final flagNotes = _flagNotesController.text.trim();

        if (flagNotes.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a reason before flagging this ID.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }

        if (verificationLogId != null && idNumber.isNotEmpty) {
          // REQ-2.6.4: Try immediate submission, auto-queue if offline
          final flagResult = await FraudFlagSyncService.submitFlagNow(
            verificationLogId: verificationLogId,
            idNumberFlagged: idNumber,
            beneficiaryType: beneficiaryType,
            notes: flagNotes,
          );

          if (flagResult['error'] != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Flag submission failed: ${flagResult['error']}'),
                backgroundColor: Colors.orange.shade800,
              ),
            );
          } else if (flagResult['queued'] == true) {
            // Flag was queued offline
            isQueued = true;
            flagReferenceNumber = flagResult['reference'] as String?;
          } else if (flagResult['flag_id'] != null) {
            // Extract first 8 chars of UUID for display
            final fullId = flagResult['flag_id'] as String;
            flagReferenceNumber = fullId.substring(0, 8).toUpperCase();
          }
        }
      }

      await database.insertScannedID(
        fullName: widget.parsedData.fullName ?? '',
        idNumber: idNumber,
        age: widget.parsedData.age,
        sex: widget.parsedData.sex ?? '',
        dateIssued: widget.parsedData.dateIssued ?? '',
        controlNumber: widget.parsedData.controlNumber ?? '',
        imagePath: widget.imagePath,
        idType: widget.idType,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        verificationStatus: flagged ? 'flagged' : _status.name,
        establishmentId: ApiService.currentUser?['id']?.toString(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(flagged
              ? (flagReferenceNumber != null
                  ? (isQueued
                      ? 'Flag queued offline. Ref: $flagReferenceNumber (will sync when online)'
                      : 'Flag submitted successfully. Reference: $flagReferenceNumber')
                  : 'ID saved and flagged successfully.')
              : 'ID saved successfully.'),
          backgroundColor: flagged
              ? (isQueued ? Colors.blue.shade700 : Colors.orange.shade700)
              : const Color(0xFF13BB11),
          duration: const Duration(seconds: 5),
        ),
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving result: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// REQ-2.6.5: Prompt user to select beneficiary type when INVALID
  Future<String?> _promptBeneficiaryType() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Beneficiary Type'),
          content: const Text(
            'This ID was not found in our database. Please select the beneficiary type to route the flag report to the correct LGU office:',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'senior_citizen'),
              icon: const Icon(Icons.elderly),
              label: const Text('Senior Citizen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002E6B),
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'pwd'),
              icon: const Icon(Icons.accessible),
              label: const Text('PWD'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002E6B),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _isLowConfidence =>
      widget.verificationResult?.message?.contains('Low OCR confidence') ==
      true;

  String? get _cleanMessage {
    final msg = widget.verificationResult?.message;
    if (msg == null) return null;
    // Strip the low-confidence prefix — it's shown in the dedicated banner
    return msg.replaceFirst(RegExp(r'^\(Low OCR confidence[^)]*\)\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(_status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Result'),
        centerTitle: true,
        backgroundColor: const Color(0xFF002E6B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(cfg),
              if (_isLowConfidence) ...[
                const SizedBox(height: 10),
                _buildLowConfidenceWarning()
              ],
              const SizedBox(height: 16),
              _buildImagePreview(),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 20),
              if (_canFlag) ...[
                _buildFlagReasonInput(),
                const SizedBox(height: 10),
                _buildActionButton(
                  label: 'Flag & Save',
                  icon: Icons.flag,
                  color: Colors.red.shade700,
                  onPressed:
                      _isSaving ? null : () => _saveToDatabase(flagged: true),
                ),
                const SizedBox(height: 10),
                _buildActionButton(
                  label: 'Save Only',
                  icon: Icons.save,
                  color: const Color(0xFF002E6B),
                  onPressed:
                      _isSaving ? null : () => _saveToDatabase(flagged: false),
                ),
              ] else
                _buildActionButton(
                  label: 'Save Result',
                  icon: Icons.save,
                  color: const Color(0xFF002E6B),
                  onPressed:
                      _isSaving ? null : () => _saveToDatabase(flagged: false),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLowConfidenceWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFA726)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Low OCR confidence — the ID image was unclear. '
              'Verify the result manually if uncertain.',
              style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagReasonInput() {
    return TextField(
      controller: _flagNotesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Reason for flagging',
        hintText: 'Enter why this ID is suspicious or invalid',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF002E6B), width: 2),
        ),
      ),
    );
  }

  Widget _buildStatusCard(_StatusConfig cfg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cfg.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cfg.border, width: 2),
      ),
      child: Row(
        children: [
          Icon(cfg.icon, color: Colors.white, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cfg.subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(widget.imagePath),
        height: 220,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildSummaryCard() {
    final isPWD = widget.idType == 'pwd';
    final apiName = widget.verificationResult?.beneficiaryName;
    final displayName = (apiName != null && apiName.isNotEmpty)
        ? apiName
        : (widget.parsedData.fullName ?? 'N/A');
    final displayStatus =
        widget.verificationResult?.displayStatus ?? 'MANUAL REVIEW';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Result Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _row('Verification', displayStatus),
          _row('Name', displayName),
          if (isPWD) ...[
            _row('Type of Disability',
                widget.parsedData.disabilityType ?? 'N/A'),
            _row(
              'ID No.',
              widget.parsedData.controlNumber ??
                  widget.parsedData.idNumber ??
                  'N/A',
            ),
          ] else ...[
            _row('Control Number', widget.parsedData.controlNumber ?? 'N/A'),
            _row(
              'Age',
              widget.parsedData.age != null
                  ? '${widget.parsedData.age}'
                  : 'N/A',
            ),
            _row('Sex', widget.parsedData.sex ?? 'N/A'),
            _row('Date Issued', widget.parsedData.dateIssued ?? 'N/A'),
          ],
        ],
      ),
    );
  }

  Widget _row(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$key:',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(
          _isSaving ? 'Saving...' : label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  _StatusConfig _statusConfig(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.valid:
        return _StatusConfig(
          label: 'VALID ID',
          subtitle: _cleanMessage ?? 'ID verified successfully.',
          icon: Icons.verified_user,
          background: const Color(0xFF13BB11),
          border: const Color(0xFF0D8A0C),
        );
      case VerificationStatus.suspicious:
        return _StatusConfig(
          label: 'SUSPICIOUS ID',
          subtitle: _cleanMessage ?? 'Record found but requires review.',
          icon: Icons.warning_amber_rounded,
          background: Colors.orange.shade700,
          border: Colors.orange.shade900,
        );
      case VerificationStatus.invalid:
        return _StatusConfig(
          label: 'INVALID ID',
          subtitle: _cleanMessage ?? 'ID not found in records.',
          icon: Icons.cancel,
          background: const Color(0xFFD32F2F),
          border: const Color(0xFF9A0007),
        );
      case VerificationStatus.error:
        return _StatusConfig(
          label: 'VERIFICATION ERROR',
          subtitle: widget.verificationResult?.errorMessage ??
              'Could not reach server.',
          icon: Icons.error_outline,
          background: const Color(0xFFD32F2F),
          border: const Color(0xFF9A0007),
        );
      case VerificationStatus.manualReview:
        return _StatusConfig(
          label: 'MANUAL REVIEW',
          subtitle: _cleanMessage ?? 'Unable to verify automatically.',
          icon: Icons.help_outline,
          background: const Color(0xFF455A64),
          border: const Color(0xFF263238),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color border;

  _StatusConfig({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.border,
  });
}
