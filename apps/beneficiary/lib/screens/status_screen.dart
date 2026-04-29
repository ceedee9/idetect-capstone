import 'package:flutter/material.dart';
import '../core/constants/app_design_system.dart';
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
      setState(() {
        _profile = profile;
        _isLoading = profile == null;
        _error = profile == null
            ? 'Could not load your profile. Pull to refresh.'
            : null;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppDesignSystem.statusValid;
      case 'expired':
        return Colors.orange;
      case 'suspended':
        return AppDesignSystem.statusFlagged;
      case 'revoked':
        return AppDesignSystem.statusInvalid;
      default:
        return AppDesignSystem.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'expired':
        return Icons.schedule;
      case 'suspended':
        return Icons.warning_amber_rounded;
      case 'revoked':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
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
                  Icons.cloud_off,
                  size: 64,
                  color: AppDesignSystem.textTertiary,
                ),
                const SizedBox(height: AppDesignSystem.spaceSM),
                Text(_error!, style: AppDesignSystem.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    final color = _statusColor(p.status);

    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.screenPaddingHorizontal),
      children: [
        const SizedBox(height: AppDesignSystem.spaceXS),

        // ── Status Card ──
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spaceMD),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppDesignSystem.primaryBlue,
                AppDesignSystem.primaryBlue.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppDesignSystem.cardRadius,
            boxShadow: AppDesignSystem.shadowMD,
          ),
          child: Column(
            children: [
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusFull,
                  ),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(p.status), color: color, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      p.status.toUpperCase(),
                      style: AppDesignSystem.buttonMedium.copyWith(
                        color: color,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDesignSystem.spaceSM),

              // Name
              Text(
                p.fullName,
                style: AppDesignSystem.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // ID Number
              Text(
                p.idNumber,
                style: AppDesignSystem.bodyLarge.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppDesignSystem.spaceSM),

              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusFull,
                  ),
                ),
                child: Text(
                  p.beneficiaryType.replaceAll('_', ' ').toUpperCase(),
                  style: AppDesignSystem.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),

              if (p.statusReason != null) ...[
                const SizedBox(height: AppDesignSystem.spaceSM),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppDesignSystem.radiusSM,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.statusReason!,
                          style: AppDesignSystem.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDesignSystem.spaceMD),

        // ── Expiry Warning Banner ──
        if (p.isActive && p.daysUntilExpiry != null && p.daysUntilExpiry! <= 30)
          _buildExpiryBanner(p.daysUntilExpiry!),

        // ── ID Details ──
        _buildSection('ID Details', [
          _buildDetailRow('Issuing Office', p.issuingOffice),
          _buildDetailRow('Valid From', p.validityStart),
          _buildDetailRow('Valid Until', p.validityEnd),
          _buildDetailRow('Birthdate', p.birthdate),
          if (p.registeredMobile != null)
            _buildDetailRow('Mobile', p.registeredMobile!),
        ]),
        const SizedBox(height: AppDesignSystem.spaceSM),

        // ── Quick Stats ──
        _buildSection('Activity Summary', [
          _buildStatRow(
            Icons.verified,
            'Total Verifications',
            '${p.totalVerifications}',
            AppDesignSystem.secondaryBlue,
          ),
          _buildStatRow(
            Icons.flag_outlined,
            'Pending Flags',
            '${p.pendingFlags}',
            p.pendingFlags > 0
                ? AppDesignSystem.statusFlagged
                : AppDesignSystem.textSecondary,
          ),
          _buildStatRow(
            Icons.gavel,
            'Active Disputes',
            '${p.activeDisputes}',
            p.activeDisputes > 0
                ? Colors.orange
                : AppDesignSystem.textSecondary,
          ),
        ]),
        const SizedBox(height: AppDesignSystem.spaceMD),

        // ── Report Fraud Button ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FraudReportScreen()),
              );
            },
            icon: const Icon(
              Icons.report_outlined,
              color: AppDesignSystem.accentRed,
            ),
            label: Text(
              'Report Fraud on My ID',
              style: AppDesignSystem.buttonMedium.copyWith(
                color: AppDesignSystem.accentRed,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppDesignSystem.accentRed),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: AppDesignSystem.buttonRadius,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spaceLG),
      ],
    );
  }

  Widget _buildExpiryBanner(int daysLeft) {
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
        ? 'Your ID expires today!'
        : daysLeft == 1
        ? 'Your ID expires tomorrow!'
        : 'Your ID expires in $daysLeft days';

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
                  'Please visit your issuing office to renew your ID.',
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: AppDesignSystem.heading4),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppDesignSystem.bodyMedium.copyWith(
              color: AppDesignSystem.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppDesignSystem.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppDesignSystem.bodyMedium)),
          Text(value, style: AppDesignSystem.heading4.copyWith(color: color)),
        ],
      ),
    );
  }
}
