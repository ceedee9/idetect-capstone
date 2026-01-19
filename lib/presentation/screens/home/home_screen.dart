import 'package:flutter/material.dart';
import '../../../core/constants/app_design_system.dart'; // Import design system!
import '../scan/custom_camera_screen.dart'; // Custom camera with ID framing

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundWhite,
      appBar: AppBar(
        title: const Text('iDetect'),
        backgroundColor: AppDesignSystem.primaryBlue,
        foregroundColor: AppDesignSystem.textOnPrimary,
      ),
      body: Padding(
        padding: EdgeInsets.all(AppDesignSystem.screenPaddingHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo placeholder
            Container(
              width: 120,
              height: 60,
              color: AppDesignSystem.primaryBlue,
              child: Center(
                child: Text(
                  'iDetect',
                  style: AppDesignSystem.heading2,
                ),
              ),
            ),

            SizedBox(height: AppDesignSystem.spaceLG),

            Text(
              'Welcome to iDetect',
              style: AppDesignSystem.heading1.copyWith(
                color: AppDesignSystem.textPrimary,
              ),
            ),

            SizedBox(height: AppDesignSystem.spaceMD),

            Text(
              'OCR-based ID Verification System',
              style: AppDesignSystem.bodyLarge,
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppDesignSystem.spaceXL),

            // Test primary button with design system
            ElevatedButton(
              style: AppDesignSystem.primaryButton,
              onPressed: () => _showIDTypeDialog(context),
              child: const Text('Scan ID'),
            ),

            SizedBox(height: AppDesignSystem.spaceSM),

            // Test status badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusBadge('valid'),
                _buildStatusBadge('invalid'),
                _buildStatusBadge('flagged'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show ID type selection dialog before opening camera
  void _showIDTypeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Select ID Type',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What type of ID are you scanning?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Senior Citizen ID button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CustomCameraScreen(idType: 'senior'),
                    ),
                  );
                },
                icon: const Icon(Icons.elderly, size: 32),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Senior Citizen ID',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // PWD ID button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CustomCameraScreen(idType: 'pwd'),
                    ),
                  );
                },
                icon: const Icon(Icons.accessible, size: 32),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'PWD ID',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade500,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spaceSM,
        vertical: AppDesignSystem.spaceXS,
      ),
      decoration: BoxDecoration(
        color: AppDesignSystem.getStatusColor(status),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppDesignSystem.getStatusIcon(status),
            size: AppDesignSystem.iconSM,
            color: AppDesignSystem.textOnPrimary,
          ),
          SizedBox(width: AppDesignSystem.spaceXXS),
          Text(
            status.toUpperCase(),
            style: AppDesignSystem.statusText.copyWith(
              color: AppDesignSystem.textOnPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
