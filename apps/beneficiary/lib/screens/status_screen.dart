import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'fraud_report_screen.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  BeneficiaryProfile? _profile;
  bool _isLoading = true;
  bool _isIdNumberVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final profile = await ApiService.getProfile();
    if (mounted) {
      final loc = AppLocalizations.of(context)!;
      setState(() {
        _profile = profile;
        _isLoading = profile == null;
        _error = profile == null ? loc.statusErrorLoadProfile : null;
      });
    }
  }

  Color _statusColor(String status) {
    return AppDesignSystem.getStatusColor(status);
  }

  IconData _statusIcon(String status) {
    return AppDesignSystem.getStatusIcon(status);
  }

  String _statusLabel(String status, AppLocalizations loc) {
    switch (status) {
      case 'active':
        return loc.beneficiaryStatusActive;
      case 'expired':
        return loc.beneficiaryStatusExpired;
      case 'suspended':
        return loc.beneficiaryStatusSuspended;
      case 'revoked':
        return loc.beneficiaryStatusRevoked;
      default:
        return loc.beneficiaryStatusUnknown;
    }
  }

  String _formatDate(String value, AppLocalizations loc) {
    try {
      return DateFormat.yMMMd(loc.localeName).format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  String _beneficiaryTypeLabel(String rawType, AppLocalizations loc) {
    switch (rawType) {
      case 'senior_citizen':
        return loc.beneficiaryTypeSenior;
      case 'pwd':
        return loc.beneficiaryTypePwd;
      default:
        return rawType.replaceAll('_', ' ');
    }
  }

  String _maskedIdNumber(String idNumber) {
    final visibleCharacters = idNumber.length < 2 ? idNumber.length : 2;
    final hiddenCharacters = List.filled(
      idNumber.length - visibleCharacters,
      '•',
    ).join();
    return '$hiddenCharacters${idNumber.substring(idNumber.length - visibleCharacters)}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: AppDesignSystem.primaryBlue,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppDesignSystem.primaryBlue,
              ),
            )
          : _error != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 72,
                  color: AppDesignSystem.textHint,
                ),
                const SizedBox(height: AppDesignSystem.spaceSM),
                Text(
                  _error!,
                  style: AppDesignSystem.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final loc = AppLocalizations.of(context)!;
    final p = _profile!;
    final color = _statusColor(p.status);

    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.screenPaddingHorizontal),
      children: [
        const SizedBox(height: AppDesignSystem.spaceXS),

        // ── Status Card ──
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spaceSM),
          decoration: BoxDecoration(
            color: AppDesignSystem.backgroundWhite,
            borderRadius: AppDesignSystem.cardRadius,
            border: Border.all(color: AppDesignSystem.borderLight),
            boxShadow: AppDesignSystem.shadowSM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  border: Border.all(color: color.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusFull,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(p.status), color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _statusLabel(p.status, loc),
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDesignSystem.spaceSM),
              Text(
                p.fullName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: AppDesignSystem.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _beneficiaryTypeLabel(p.beneficiaryType, loc),
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesignSystem.spaceSM),
              const Divider(height: 1),
              const SizedBox(height: AppDesignSystem.spaceSM),
              Text(loc.statusIdNumberLabel, style: AppDesignSystem.label),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: _isIdNumberVisible
                          ? '${loc.statusIdNumberLabel}: ${p.idNumber}'
                          : loc.statusIdNumberHidden(
                              p.idNumber.length <= 2
                                  ? p.idNumber
                                  : p.idNumber.substring(p.idNumber.length - 2),
                            ),
                      child: ExcludeSemantics(
                        child: Text(
                          _isIdNumberVisible
                              ? p.idNumber
                              : _maskedIdNumber(p.idNumber),
                          style: AppDesignSystem.bodyMedium.copyWith(
                            color: AppDesignSystem.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _isIdNumberVisible
                        ? loc.statusHideIdNumber
                        : loc.statusShowIdNumber,
                    onPressed: () => setState(
                      () => _isIdNumberVisible = !_isIdNumberVisible,
                    ),
                    icon: Icon(
                      _isIdNumberVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    color: AppDesignSystem.interactiveBlue,
                  ),
                ],
              ),
              if (p.statusReason != null) ...[
                const Divider(height: AppDesignSystem.spaceMD),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.statusReason!,
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),

        // ── Expiry Warning Banner ──
        if (p.isActive && p.daysUntilExpiry != null && p.daysUntilExpiry! <= 30)
          _buildExpiryBanner(p.daysUntilExpiry!, loc),

        // ── ID Details ──
        _buildSection(loc.statusIdDetailsTitle, [
          _buildDetailRow(loc.statusIssuingOffice, p.issuingOffice),
          _buildDetailRow(
            loc.statusValidFrom,
            _formatDate(p.validityStart, loc),
          ),
          _buildDetailRow(
            loc.statusValidUntil,
            _formatDate(p.validityEnd, loc),
          ),
          _buildDetailRow(loc.statusBirthdate, _formatDate(p.birthdate, loc)),
          if (p.registeredMobile != null)
            _buildDetailRow(loc.statusMobile, p.registeredMobile!),
        ]),
        const SizedBox(height: AppDesignSystem.spaceSM),

        // ── Quick Stats ──
        _buildSection(loc.statusActivitySummaryTitle, [
          _buildStatRow(
            Icons.verified_rounded,
            loc.statusTotalVerifications,
            '${p.totalVerifications}',
            AppDesignSystem.interactiveBlue,
          ),
          _buildStatRow(
            Icons.flag_rounded,
            loc.statusPendingFlags,
            '${p.pendingFlags}',
            p.pendingFlags > 0
                ? AppDesignSystem.statusFlagged
                : AppDesignSystem.textSecondary,
          ),
          _buildStatRow(
            Icons.gavel_rounded,
            loc.statusActiveDisputes,
            '${p.activeDisputes}',
            p.activeDisputes > 0
                ? AppDesignSystem.statusWarning
                : AppDesignSystem.textSecondary,
          ),
        ]),
        const SizedBox(height: AppDesignSystem.spaceMD),

        // ── Report Fraud Button ──
        Semantics(
          label: loc.statusReportFraudSemantics,
          child: SizedBox(
            width: double.infinity,
            height: AppDesignSystem.touchTargetPrimary,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FraudReportScreen()),
                );
              },
              icon: const Icon(
                Icons.report_problem_rounded,
                color: AppDesignSystem.accentRed,
                size: 24,
              ),
              label: Text(
                loc.statusReportFraudButton,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.accentRed,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: AppDesignSystem.accentRed,
                  width: 2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppDesignSystem.buttonRadius,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spaceLG),
      ],
    );
  }

  Widget _buildExpiryBanner(int daysLeft, AppLocalizations loc) {
    final isUrgent = daysLeft <= 7;
    final color = daysLeft <= 1
        ? AppDesignSystem.statusInvalid
        : daysLeft <= 7
        ? Colors.orange
        : Colors.amber.shade700;
    final bgColor = daysLeft <= 1
        ? Colors.red.shade50
        : daysLeft <= 7
        ? Colors.orange.shade50
        : Colors.amber.shade50;
    final label = daysLeft == 0
        ? loc.statusExpiresToday
        : daysLeft == 1
        ? loc.statusExpiresTomorrow
        : loc.statusExpiresInDays(daysLeft);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spaceMD),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppDesignSystem.cardRadius,
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.schedule,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppDesignSystem.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.statusRenewInstruction,
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppDesignSystem.borderLight),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: AppDesignSystem.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                color: AppDesignSystem.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
