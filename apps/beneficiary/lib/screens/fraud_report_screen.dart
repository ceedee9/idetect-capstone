import 'package:flutter/material.dart';
import '../core/constants/app_design_system.dart';
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

  final _types = <String, _FraudType>{
    'unauthorized_use': _FraudType(
      icon: Icons.person_off_outlined,
      label: 'Unauthorized Use',
      desc: 'Someone used my ID without my permission',
    ),
    'stolen_id': _FraudType(
      icon: Icons.warning_amber_rounded,
      label: 'Stolen ID',
      desc: 'My physical ID card was stolen',
    ),
    'fake_id': _FraudType(
      icon: Icons.content_copy_outlined,
      label: 'Fake / Cloned ID',
      desc: 'Someone created a copy of my ID',
    ),
    'other': _FraudType(
      icon: Icons.report_outlined,
      label: 'Other',
      desc: 'Another type of fraud or misuse',
    ),
  };

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the incident')),
      );
      return;
    }

    setState(() => _submitting = true);

    final result = await ApiService.submitFraudReport(
      reportType: _selectedType,
      description: _descCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['error'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fraud report submitted successfully'),
          backgroundColor: AppDesignSystem.statusValid,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit report. Please try again.'),
          backgroundColor: AppDesignSystem.statusInvalid,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Report Fraud', style: AppDesignSystem.heading3),
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
                      'Filing a fraud report will immediately flag your ID for review. This helps protect your benefits.',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: AppDesignSystem.accentRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceMD),

            // Type selection
            Text('What happened?', style: AppDesignSystem.heading4),
            const SizedBox(height: AppDesignSystem.spaceSM),

            ..._types.entries.map((e) {
              final active = e.key == _selectedType;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDesignSystem.spaceXS),
                child: InkWell(
                  borderRadius: AppDesignSystem.cardRadius,
                  onTap: () => setState(() => _selectedType = e.key),
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
              );
            }),

            const SizedBox(height: AppDesignSystem.spaceMD),

            // Description
            Text('Describe the incident', style: AppDesignSystem.heading4),
            const SizedBox(height: AppDesignSystem.spaceSM),
            TextField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: AppDesignSystem.inputDecoration(
                hintText:
                    'Provide details: when, where, and how you discovered the fraud...',
              ),
            ),
            const SizedBox(height: AppDesignSystem.spaceLG),

            // Submit
            SizedBox(
              width: double.infinity,
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
                label: Text(
                  _submitting ? 'Submitting...' : 'Submit Report',
                  style: AppDesignSystem.buttonMedium,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.accentRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
