import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class FraudReportScreen extends StatefulWidget {
  const FraudReportScreen({super.key});

  @override
  State<FraudReportScreen> createState() => _FraudReportScreenState();
}

class _FraudReportScreenState extends State<FraudReportScreen> {
  String _selectedType = 'unauthorized_use';
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  // Icons + report-type keys stay here; labels/descriptions now come
  // from AppLocalizations (built in _typesFor below) since they need
  // to switch with the language toggle like every other screen.
  static const _typeIcons = <String, IconData>{
    'unauthorized_use': Icons.person_off_outlined,
    'stolen_id': Icons.warning_amber_rounded,
    'fake_id': Icons.content_copy_outlined,
    'other': Icons.report_outlined,
  };

  Map<String, _FraudType> _typesFor(AppLocalizations loc) => {
    'unauthorized_use': _FraudType(
      icon: _typeIcons['unauthorized_use']!,
      label: loc.fraudTypeUnauthorizedLabel,
      desc: loc.fraudTypeUnauthorizedDesc,
    ),
    'stolen_id': _FraudType(
      icon: _typeIcons['stolen_id']!,
      label: loc.fraudTypeStolenLabel,
      desc: loc.fraudTypeStolenDesc,
    ),
    'fake_id': _FraudType(
      icon: _typeIcons['fake_id']!,
      label: loc.fraudTypeFakeLabel,
      desc: loc.fraudTypeFakeDesc,
    ),
    'other': _FraudType(
      icon: _typeIcons['other']!,
      label: loc.fraudTypeOtherLabel,
      desc: loc.fraudTypeOtherDesc,
    ),
  };

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.fraudReportErrorEmptyDescription)),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    final result = await ApiService.submitFraudReport(
      reportType: _selectedType,
      description: _descCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['error'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.fraudReportSuccessSnackbar),
          backgroundColor: AppDesignSystem.statusValid,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.fraudReportErrorSnackbar),
          backgroundColor: AppDesignSystem.statusInvalid,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final types = _typesFor(loc);

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundWarm,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(loc.fraudReportTitle, style: AppDesignSystem.heading3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDesignSystem.screenPaddingHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDesignSystem.spaceSM),

            // Warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.accentRed.withOpacity(0.08),
                borderRadius: AppDesignSystem.cardRadius,
                border: Border.all(
                  color: AppDesignSystem.accentRed.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppDesignSystem.accentRed,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.fraudReportWarningBanner,
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: AppDesignSystem.accentRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),

            // Type selection — functions as a radio group, so each
            // option now carries Semantics(selected:) for screen
            // readers, matching how the bottom nav tabs are handled.
            Text(loc.fraudReportWhatHappened, style: AppDesignSystem.heading4),
            const SizedBox(height: AppDesignSystem.spaceSM),

            ...types.entries.map((e) {
              final active = e.key == _selectedType;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDesignSystem.spaceXS),
                child: Semantics(
                  label: '${e.value.label}. ${e.value.desc}',
                  selected: active,
                  button: true,
                  child: InkWell(
                    borderRadius: AppDesignSystem.cardRadius,
                    onTap: () {
                      if (!active) HapticFeedback.selectionClick();
                      setState(() => _selectedType = e.key);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: active
                            ? AppDesignSystem.primaryBlue.withOpacity(0.06)
                            : Colors.white,
                        borderRadius: AppDesignSystem.cardRadius,
                        border: Border.all(
                          color: active
                              ? AppDesignSystem.primaryBlue
                              : AppDesignSystem.borderLight,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            e.value.icon,
                            color: active
                                ? AppDesignSystem.primaryBlue
                                : AppDesignSystem.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.value.label,
                                  style: AppDesignSystem.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? AppDesignSystem.primaryBlue
                                        : AppDesignSystem.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  e.value.desc,
                                  style: AppDesignSystem.caption,
                                ),
                              ],
                            ),
                          ),
                          if (active)
                            const Icon(
                              Icons.check_circle,
                              color: AppDesignSystem.primaryBlue,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: AppDesignSystem.spaceMD),

            // Description
            Text(
              loc.fraudReportDescribeIncident,
              style: AppDesignSystem.heading4,
            ),
            const SizedBox(height: AppDesignSystem.spaceSM),
            TextField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: AppDesignSystem.inputDecoration(
                hintText: loc.fraudReportDescriptionHint,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),

            // Submit — explicit 64dp, matching the touchTargetPrimary
            // convention used for primary CTAs elsewhere (this button
            // previously had no explicit height at all).
            SizedBox(
              width: double.infinity,
              height: AppDesignSystem.touchTargetPrimary,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _submitting
                        ? loc.fraudReportSubmitting
                        : loc.fraudReportSubmitButton,
                    style: AppDesignSystem.buttonMedium,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.accentRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesignSystem.buttonRadius,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),
          ],
        ),
      ),
    );
  }
}

class _FraudType {
  final IconData icon;
  final String label;
  final String desc;
  const _FraudType({
    required this.icon,
    required this.label,
    required this.desc,
  });
}
