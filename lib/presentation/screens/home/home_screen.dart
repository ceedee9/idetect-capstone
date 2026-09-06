// =============================================================================
// FILE: lib/presentation/screens/home/home_screen_redesigned.dart
// PURPOSE: New home screen based on design mockup
// FEATURES: Logo header, banner section, info cards, bottom navigation
// =============================================================================

import 'package:flutter/material.dart';
import '../../widgets/account_profile_drawer.dart';
import '../scan/camera_screen.dart';
import '../history/history_screen.dart';
import '../../../services/session_timeout_service.dart';

/// Redesigned home screen with banner and info sections
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  void _openProfileDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      // Scan ID button - show ID type selection dialog
      _showIDTypeDialog();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  /// Show ID type selection dialog before opening camera
  void _showIDTypeDialog() {
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
                  _showSeniorFormatDialog();
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
                  backgroundColor: const Color(0xFF002E6B),
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
                      builder: (context) => const CameraScreen(idType: 'pwd'),
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
                  backgroundColor: const Color(0xFF002E6B),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Auto-detect option
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CameraScreen(idType: 'auto'),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 28),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Text('Auto-detect', style: TextStyle(fontSize: 16)),
                      Text(
                        'System will identify the ID type',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
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

  /// Ask which Senior ID format was presented — old, or new (with holographic seal).
  /// Only shown for the Senior Citizen path; PWD and Auto-detect are unaffected.
  void _showSeniorFormatDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Which ID format?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Check for a round holographic seal near the signature.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Has seal, labeled "ID No." → New\nNo seal, labeled "Control No." → Old',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _onSeniorFormatSelected('old');
                },
                icon: const Icon(Icons.badge_outlined, size: 28),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Old format', style: TextStyle(fontSize: 16)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002E6B),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _onSeniorFormatSelected('new');
                },
                icon: const Icon(Icons.verified_outlined, size: 28),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('New format (with seal)',
                      style: TextStyle(fontSize: 16)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002E6B),
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

  void _onSeniorFormatSelected(String format) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(idType: 'senior', idFormat: format),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(onProfileTap: _openProfileDrawer),
      const SizedBox(), // Placeholder for scan (handled by button)
      const HistoryScreen(), // REQ-2.16.5: API-backed verification history + compliance report
    ];

    return SessionActivityWrapper(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        endDrawer: const AccountProfileDrawer(),
        body: _selectedIndex == 1 ? const SizedBox() : pages[_selectedIndex],
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                label: 'HOME',
                index: 0,
              ),
              _buildScanButton(),
              _buildNavItem(
                icon: Icons.history,
                label: 'HISTORY',
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? const Color(0xFF002E6B) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF002E6B) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return InkWell(
      onTap: () => _onItemTapped(1),
      child: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          color: Color(0xFF002E6B),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.credit_card,
                color: Color(0xFF002E6B),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HOME PAGE CONTENT
// =============================================================================

class _HomePage extends StatelessWidget {
  const _HomePage({required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildBannerSection(),
            _buildContentSection(),
            _buildCampaignImageSection(),
            _buildInfoCards(),
            const SizedBox(height: 20),
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
            onTap: onProfileTap,
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

  Widget _buildBannerSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 400,
          width: double.infinity,
          color: Colors.grey.shade200,
          child: Image.asset(
            'assets/images/campaign_1.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF002E6B).withOpacity(0.1),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignImageSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout = constraints.maxWidth >= 700;

          if (isWideLayout) {
            return Row(
              children: [
                Expanded(
                  child:
                      _buildCampaignImageCard('assets/images/campaign_2.jpg'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      _buildCampaignImageCard('assets/images/campaign_3.jpg'),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildCampaignImageCard('assets/images/campaign_2.jpg'),
              const SizedBox(height: 12),
              _buildCampaignImageCard('assets/images/campaign_3.jpg'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCampaignImageCard(String imagePath) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 280,
          width: double.infinity,
          color: Colors.white,
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF002E6B).withOpacity(0.1),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Know Your Benefits and Protect Your Community',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'iDetect supports the City of Valenzuela in promoting legitimate identification, proper benefit access, and respect for the rights of senior citizens and persons with disability (PWD).',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildPolicyCard(
            title: 'Republic Act 9994',
            subtitle: 'Expanded Senior Citizens Act of 2010',
            description:
                'Provides additional benefits and privileges for qualified senior citizens, including discounts and social support measures. Proper ID validation helps ensure these benefits reach the rightful recipients.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(
            title: 'Republic Act 10754',
            subtitle:
                'An Act Expanding the Benefits and Privileges of Persons with Disability',
            description:
                'Strengthens and expands mandatory privileges for persons with disability, including discounts and VAT exemptions. Accurate PWD ID verification protects both establishments and legitimate beneficiaries.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(
            title: 'Bawal ang Pekeng ID Campaign',
            subtitle: 'City Government of Valenzuela',
            description:
                'The campaign discourages the use of fake Senior Citizen and PWD IDs. Through consistent validation, the city promotes fairness, prevents fraud, and preserves trust in public and private services.',
            isCampaign: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard({
    required String title,
    required String subtitle,
    required String description,
    bool isCampaign = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCampaign ? const Color(0xFFEAF3FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCampaign ? const Color(0xFF5A8DCC) : const Color(0xFFD8DEE9),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCampaign
                  ? const Color(0xFF003A8C)
                  : const Color(0xFF002E6B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isCampaign
                  ? const Color(0xFF2D5F9A)
                  : const Color(0xFF355C9A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildInfoCard('assets/images/poster_senior_pwd.jpg',
                      'New Senior Citizen & PWD ID Design')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildInfoCard('assets/images/counter_display.jpg',
                      'VAL ID Validation at Establishments')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildInfoCard('assets/images/poster_person1.jpg',
                      'Verify Senior & PWD IDs Online')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildInfoCard('assets/images/poster_person2.jpg',
                      'Establishments Display Validation Info')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String imagePath, String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 100,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF002E6B).withOpacity(0.1),
                    child: const Icon(Icons.image, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF002E6B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE94444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Read More →',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
