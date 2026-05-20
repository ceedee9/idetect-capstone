import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_design_system.dart';
import '../../../data/datasources/local/local_database.dart';
import '../../../services/api_service.dart';
import '../../../services/offline_scan_sync_service.dart';
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
  // Gap 8: tracks the cashier's mandatory action choice on SUSPICIOUS/MANUAL_REVIEW.
  // null = not yet chosen; 'reported' | 'denied' | 'approved' after choice.
  String? _actionChoice;
  final TextEditingController _flagNotesController = TextEditingController();

  VerificationStatus get _status =>
      widget.verificationResult?.status ?? VerificationStatus.manualReview;

  bool get _isOffline => widget.verificationResult?.isOffline == true;

  bool get _canFlag =>
      _status == VerificationStatus.invalid ||
      _status == VerificationStatus.suspicious ||
      _status == VerificationStatus.manualReview;

  // Gap 8: suspicious and manual_review require a mandatory 3-way action choice
  // before the cashier can save/dismiss. INVALID keeps the old flag/save flow.
  bool get _requiresMandatoryChoice =>
      _status == VerificationStatus.suspicious ||
      _status == VerificationStatus.manualReview;

  @override
  void initState() {
    super.initState();
    // Pre-populate default reason so staff can tap "Flag & Save" in one tap
    if (_status == VerificationStatus.suspicious) {
      _flagNotesController.text =
          'ID record found but verification raised concerns. '
          'Customer may not be the legitimate card owner. '
          'Please verify with secondary ID.';
    } else if (_status == VerificationStatus.invalid) {
      _flagNotesController.text =
          'ID not found in database. Possible fraudulent, expired, or unknown ID.';
    }
  }

  @override
  void dispose() {
    _flagNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveToDatabase(
      {required bool flagged, String? cashierAction}) async {
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

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await database.insertScannedID(
        fullName: widget.parsedData.fullName ?? '',
        idNumber: idNumber,
        age: widget.parsedData.age,
        sex: widget.parsedData.sex ?? '',
        dateIssued: widget.parsedData.dateIssued ?? '',
        controlNumber: widget.parsedData.controlNumber ?? '',
        imagePath: widget.imagePath,
        idType: widget.idType,
        timestamp: nowMs,
        verificationStatus: flagged
            ? 'flagged'
            : cashierAction != null
                ? '${_status.name}_$cashierAction'
                : _status.name,
        establishmentId: ApiService.currentUser?['id']?.toString(),
      );

      // Problem A fix: if this was an offline verification, queue the scan
      // so it is replayed to PostgreSQL verification_logs once online.
      if (_isOffline) {
        await OfflineScanSyncService.queueOfflineScan(
          idNumber: idNumber,
          beneficiaryType: widget.idType == 'senior' ? 'senior_citizen' : 'pwd',
          extractedName: widget.parsedData.fullName,
          extractedDob: widget.parsedData.dateOfBirth,
          ocrConfidence: widget.parsedData.confidence,
          imagePath: widget.imagePath,
          scannedAt: nowMs,
        );
      }

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

      // Gap 4: Delete all local temp image files created during OCR processing.
      // The image was already uploaded to the server (base64 via verifyId()) before
      // this screen loaded, so local copies no longer serve any purpose.
      await _deleteTempImageFiles(widget.imagePath);

      // Gap 8: Log the cashier's explicit action choice to the server for audit.
      // Fire-and-forget — a network error here must never block navigation.
      final logId = widget.verificationResult?.verificationId;
      if (cashierAction != null && logId != null) {
        ApiService.logCashierAction(
          verificationId: logId,
          action: cashierAction,
        ).catchError((_) {});
      }

      if (!mounted) return;
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

  /// Gap 4: Delete the captured image and all intermediate OCR temp files.
  /// Uses a fire-and-forget approach (non-fatal on any I/O error) so a cleanup
  /// failure never blocks the user from finishing a scan.
  Future<void> _deleteTempImageFiles(String imagePath) async {
    // Derive expected derivative filenames from the original path.
    // Matches the suffix patterns used by OpenCV, Tesseract, and optimized pipelines.
    final base = imagePath.replaceAll(RegExp(r'\.(jpg|jpeg|png)$'), '');
    final candidates = [
      imagePath, // original captured & cropped image
      '${base}_ocr.jpg', // OpenCV preprocessed output
      '${base}_processed.jpg', // Tesseract / advanced preprocessed output
      '${base}_optimized.jpg', // Optimized OCR output
    ];
    for (final p in candidates) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Non-fatal — silently ignore individual cleanup errors.
      }
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
      widget.verificationResult?.message?.contains('Low extraction quality') ==
      true;

  /// True when the server returned MANUAL_REVIEW but the ID was found in the
  /// database (beneficiary name present). In this case we know the ID is valid
  /// — OCR just failed to confirm the cardholder — so we display it as VALID
  /// with a physical-verification banner, not the ambiguous "MANUAL REVIEW" label.
  bool get _isManualReviewWithRecord =>
      _status == VerificationStatus.manualReview &&
      widget.verificationResult?.beneficiaryName != null;

  String? get _cleanMessage {
    final msg = widget.verificationResult?.message;
    if (msg == null) return null;
    // Strip the low-extraction-quality prefix — it's shown in the dedicated banner
    return msg.replaceFirst(RegExp(r'^\(Low extraction quality[^)]*\)\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(_status);

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        title: _isOffline
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Verification Result'),
                  Text(
                    'OFFLINE MODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFCCBC),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              )
            : const Text('Verification Result'),
        centerTitle: true,
        backgroundColor:
            _isOffline ? const Color(0xFFBF360C) : AppDesignSystem.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isOffline) ...[
                _buildOfflineBanner(),
                const SizedBox(height: 10)
              ],
              _buildStatusCard(cfg),
              if (_isLowConfidence) ...[
                const SizedBox(height: 10),
                _buildLowConfidenceWarning()
              ],
              const SizedBox(height: 14),
              _buildImagePreview(),
              const SizedBox(height: 14),
              _buildSummaryCard(),
              const SizedBox(height: 20),
              if (_requiresMandatoryChoice) ...[
                _buildGuidancePanel(),
                const SizedBox(height: 12),
                if (_actionChoice == null) ...[
                  _buildMandatoryActionPanel(),
                ] else if (_actionChoice == 'reported') ...[
                  _buildFlagReasonInput(),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    label: 'Submit Report & Save',
                    icon: Icons.flag_rounded,
                    color: AppDesignSystem.statusInvalid,
                    onPressed: _isSaving
                        ? null
                        : () => _saveToDatabase(
                              flagged: true,
                              cashierAction: 'reported',
                            ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => setState(() => _actionChoice = null),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Change choice'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesignSystem.textSecondary,
                    ),
                  ),
                ],
              ] else if (_canFlag) ...[
                _buildGuidancePanel(),
                const SizedBox(height: 12),
                _buildFlagReasonInput(),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Flag & Save',
                  icon: Icons.flag_rounded,
                  color: AppDesignSystem.statusInvalid,
                  onPressed:
                      _isSaving ? null : () => _saveToDatabase(flagged: true),
                ),
                const SizedBox(height: 10),
                _buildActionButton(
                  label: 'Save Without Flagging',
                  icon: Icons.save_rounded,
                  color: AppDesignSystem.textSecondary,
                  onPressed:
                      _isSaving ? null : () => _saveToDatabase(flagged: false),
                ),
              ] else
                _buildActionButton(
                  label: 'Save Result',
                  icon: Icons.save_rounded,
                  color: AppDesignSystem.primaryBlue,
                  onPressed:
                      _isSaving ? null : () => _saveToDatabase(flagged: false),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Problem B fix: prominent full-width banner that makes offline results
  /// visually unmistakable from live server results.
  Widget _buildOfflineBanner() {
    final syncedAt = widget.verificationResult?.offlineSyncedAt;
    final age = syncedAt != null ? DateTime.now().difference(syncedAt) : null;
    final ageText = age == null
        ? 'an unknown time'
        : age.inHours > 0
            ? '${age.inHours}h ${age.inMinutes.remainder(60)}m ago'
            : '${age.inMinutes}m ago';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFBF360C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7F0000), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'OFFLINE RESULT — SERVER UNREACHABLE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This result is based on a cached scan from $ageText. '
            'It may NOT reflect the ID\'s current status on the server.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Do not approve high-value transactions based on an offline result. '
            'Verify online when possible.',
            style: TextStyle(
              color: Color(0xFFFFCCBC),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'This scan will be automatically synced to the server when connectivity is restored.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
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
              'Low extraction quality score — the ID image may have been unclear. '
              'Verify the result manually against the physical card.',
              style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidancePanel() {
    final isManualReview = _status == VerificationStatus.manualReview;
    final isSuspicious = _status == VerificationStatus.suspicious;

    final Color color;
    final Color borderColor;
    final Color bgColor;
    if (isManualReview && _isManualReviewWithRecord) {
      // ID is in database — use a warning-amber tone to signal "valid but check person"
      color = const Color(0xFF6A3E00);
      borderColor = const Color(0xFFFFCC02);
      bgColor = const Color(0xFFFFF9E6);
    } else if (isManualReview) {
      color = const Color(0xFF455A64);
      borderColor = const Color(0xFF90A4AE);
      bgColor = const Color(0xFFECEFF1);
    } else if (isSuspicious) {
      color = Colors.orange.shade700;
      borderColor = Colors.orange.shade300;
      bgColor = const Color(0xFFFFF8E1);
    } else {
      color = const Color(0xFFD32F2F);
      borderColor = Colors.red.shade200;
      bgColor = const Color(0xFFFFEBEE);
    }

    final List<String> steps;
    if (isManualReview && _isManualReviewWithRecord) {
      steps = [
        'This ID is registered and VALID in the database.',
        'Compare the name shown above against the physical card.',
        'If the person matches the card, tap "Approve Anyway" to grant the discount.',
        'If anything looks wrong, tap "Deny Discount" or "Report This ID".',
      ];
    } else if (isManualReview) {
      steps = [
        'Manually check the cardholder\'s name and date of birth against the physical card.',
        'If the card appears legitimate, you may approve the discount.',
        'If anything looks wrong or suspicious, tap "Flag & Save" to report it.',
      ];
    } else if (isSuspicious) {
      steps = [
        'Do NOT approve the discount.',
        'Ask the customer for a secondary ID.',
        'Contact your supervisor or manager.',
        'Tap "Flag & Save" below to report this ID.',
      ];
    } else {
      steps = [
        'Do NOT approve the discount.',
        'This ID number is not in our database.',
        'It may be forged, expired, or belong to another system.',
        'Tap "Flag & Save" below to report this ID.',
      ];
    }

    final String panelTitle;
    if (isManualReview && _isManualReviewWithRecord) {
      panelTitle = 'Physical Verification Required';
    } else if (isManualReview) {
      panelTitle = 'Manual Verification Required';
    } else if (isSuspicious) {
      panelTitle = 'Action Required';
    } else {
      panelTitle = 'Invalid ID Detected';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                panelTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step,
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// Gap 8: mandatory 3-button action panel for SUSPICIOUS and MANUAL_REVIEW results.
  /// The cashier must tap one option; the choice is logged to the audit trail.
  Widget _buildMandatoryActionPanel() {
    final isSuspicious = _status == VerificationStatus.suspicious;
    final accentColor =
        isSuspicious ? Colors.orange.shade800 : const Color(0xFF1565C0);
    final borderColor =
        isSuspicious ? const Color(0xFFFFA726) : const Color(0xFF90CAF9);
    final bgColor =
        isSuspicious ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You must select an action before proceeding',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Report — opens the notes field so cashier can add context
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => setState(() => _actionChoice = 'reported'),
              icon: const Icon(Icons.flag_rounded, size: 20),
              label: const Text(
                'Report This ID',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Deny — cashier explicitly refuses the discount and saves
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveToDatabase(
                        flagged: false,
                        cashierAction: 'denied',
                      ),
              icon: const Icon(Icons.block_rounded, size: 20),
              label: const Text(
                'Deny Discount',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37474F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Approve Anyway — cashier overrides the warning; logged for audit
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveToDatabase(
                        flagged: false,
                        cashierAction: 'approved',
                      ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text(
                'Approve Anyway',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(color: borderColor, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: cfg.background,
        borderRadius: AppDesignSystem.cardRadius,
        border: Border.all(color: cfg.border, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: cfg.background.withOpacity(0.40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(cfg.icon, color: Colors.white, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cfg.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowSM,
        border: Border.all(color: AppDesignSystem.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Result Summary',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppDesignSystem.borderLight),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppDesignSystem.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppDesignSystem.textPrimary,
              ),
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
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: onPressed == null ? 0 : 2,
          shadowColor: color.withOpacity(0.4),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDesignSystem.buttonRadius,
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Icon(icon, size: 22),
        label: Text(
          _isSaving ? 'Saving...' : label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
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
          icon: Icons.verified_user_rounded,
          background: AppDesignSystem.statusValid,
          border: const Color(0xFF0A6000),
        );
      case VerificationStatus.suspicious:
        return _StatusConfig(
          label: 'SUSPICIOUS ID',
          subtitle: _cleanMessage ?? 'Record found but requires review.',
          icon: Icons.warning_amber_rounded,
          background: AppDesignSystem.statusSuspicious,
          border: const Color(0xFF8A3D00),
        );
      case VerificationStatus.invalid:
        return _StatusConfig(
          label: 'INVALID ID',
          subtitle: _cleanMessage ?? 'ID not found in records.',
          icon: Icons.cancel_rounded,
          background: AppDesignSystem.statusInvalid,
          border: const Color(0xFF8B0000),
        );
      case VerificationStatus.error:
        return _StatusConfig(
          label: 'VERIFICATION ERROR',
          subtitle: widget.verificationResult?.errorMessage ??
              'Could not reach server.',
          icon: Icons.error_outline_rounded,
          background: AppDesignSystem.statusInvalid,
          border: const Color(0xFF8B0000),
        );
      case VerificationStatus.manualReview:
        // If the ID was found in the database, display as VALID — the record
        // exists and is registered. The physical-check banner explains why
        // manual verification is still needed.
        if (_isManualReviewWithRecord) {
          return _StatusConfig(
            label: 'VALID ID',
            subtitle: 'ID found in database — physical verification required.',
            icon: Icons.verified_user_rounded,
            background: AppDesignSystem.statusValid,
            border: const Color(0xFF0A6000),
          );
        }
        // No database record found (e.g. ID number wasn't extracted at all).
        return _StatusConfig(
          label: 'MANUAL REVIEW',
          subtitle: _cleanMessage ?? 'Unable to verify — check ID manually.',
          icon: Icons.manage_search_rounded,
          background: AppDesignSystem.statusManualReview,
          border: const Color(0xFF0D3B8E),
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
