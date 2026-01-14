import 'package:flutter/material.dart';
import '../../../core/constants/app_design_system.dart'; // Import design system!

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
              onPressed: () {
                // TODO: Navigate to camera
              },
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
