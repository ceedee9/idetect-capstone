import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF002E6B),
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 16)),
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
                color: const Color(0xFF002E6B).withOpacity(0.1),
                child: const Icon(Icons.image, size: 48, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002E6B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade800, height: 1.5),
                  ),
                  if (externalUrl != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openExternalUrl(context),
                        icon: const Icon(Icons.open_in_new),
                        label:
                            Text(externalUrlLabel ?? 'Visit official portal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002E6B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
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
