import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_design_system.dart';

class InfoDetailScreen extends StatelessWidget {
  final String imagePath;
  final String title;
  final String body;
  final String? externalUrl;
  final String? externalUrlLabel;

  const InfoDetailScreen({
    super.key,
    required this.imagePath,
    required this.title,
    required this.body,
    this.externalUrl,
    this.externalUrlLabel,
  });

  Future<void> _openExternalUrl(BuildContext context) async {
    final uri = Uri.parse(externalUrl!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
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
        title: Text(
          'Resource',
          style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              imagePath,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 220,
                color: AppDesignSystem.backgroundLightBlue,
                child: Icon(Icons.image_outlined,
                    size: 48, color: AppDesignSystem.iconLight),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppDesignSystem.spaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESOURCE DETAIL',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 11,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: AppDesignSystem.spaceSM),
                  Text(
                    body,
                    style: AppDesignSystem.bodyMedium
                        .copyWith(color: AppDesignSystem.textSecondary),
                  ),
                  if (externalUrl != null) ...[
                    SizedBox(height: AppDesignSystem.spaceLG),
                    SizedBox(
                      width: double.infinity,
                      height: AppDesignSystem.touchTargetPrimary,
                      child: ElevatedButton.icon(
                        onPressed: () => _openExternalUrl(context),
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        label:
                            Text(externalUrlLabel ?? 'Visit official portal'),
                        style: AppDesignSystem.primaryButton,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
