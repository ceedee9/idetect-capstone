// =============================================================================
// FILE: lib/presentation/widgets/bplo_contact_card.dart
// PURPOSE: Tappable card with the BPLO phone line. Used on the home screen and
//          on login errors for suspended or otherwise restricted establishments.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_design_system.dart';

const String bploPhoneDisplay = '(02) 8352-1000 ext. 1801';

// The ",," pauses the dialer before the extension is entered.
const String _bploPhoneUri = 'tel:0283521000,,1801';

class BploContactCard extends StatelessWidget {
  final String title;
  final String? message;

  const BploContactCard({
    super.key,
    this.title = 'Need help? Contact BPLO',
    this.message,
  });

  Future<void> _call(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(_bploPhoneUri),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dialer. Call $bploPhoneDisplay.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. Call $bploPhoneDisplay',
      child: Material(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: AppDesignSystem.cardRadius,
        child: InkWell(
          borderRadius: AppDesignSystem.cardRadius,
          onTap: () => _call(context),
          child: Container(
            padding: const EdgeInsets.all(AppDesignSystem.spaceSM),
            decoration: BoxDecoration(
              borderRadius: AppDesignSystem.cardRadius,
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowSM,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.statusManualReview.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppDesignSystem.statusManualReview,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          message!,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      const Text(
                        bploPhoneDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.statusManualReview,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.call_rounded,
                  color: AppDesignSystem.statusManualReview,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
