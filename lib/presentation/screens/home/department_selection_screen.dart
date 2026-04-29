// =============================================================================
// FILE: lib/presentation/screens/home/department_selection_screen.dart
// PURPOSE: Screen to select department (PDAO or OSCA)
// FEATURES: Two department options with logos
// =============================================================================

import 'package:flutter/material.dart';
import '../../widgets/account_profile_drawer.dart';
import 'osca_records_screen.dart';
import 'pdao_records_screen.dart';

/// Department selection screen (PDAO/OSCA)
class DepartmentSelectionScreen extends StatelessWidget {
  const DepartmentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const AccountProfileDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDepartmentCard(
                      context,
                      title: 'PDAO',
                      subtitle: 'Persons with Disability Affairs Office',
                      imagePath: 'assets/images/pdao_logo.png',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PDAORecordsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildDepartmentCard(
                      context,
                      title: 'OSCA',
                      subtitle: 'Office of the Senior Citizens Affairs',
                      imagePath: 'assets/images/osca_logo.png',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OSCARecordsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Image.asset(
            'assets/images/idetect_logo.png',
            height: 60,
            fit: BoxFit.contain,
          ),
          // Profile icon button
          InkWell(
            onTap: () => Scaffold.of(context).openEndDrawer(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: const Icon(Icons.person_outline, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon/Logo placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.image,
                        size: 70,
                        color: Colors.grey,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
