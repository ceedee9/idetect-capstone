// =============================================================================
// FILE: lib/presentation/screens/home/home_screen_redesigned.dart
// PURPOSE: New home screen based on design mockup
// FEATURES: Logo header, banner section, info cards, bottom navigation
// =============================================================================

import 'package:flutter/material.dart';
import 'department_selection_screen.dart';
import '../scan/camera_screen.dart';

/// Redesigned home screen with banner and info sections
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Pages for bottom navigation
  final List<Widget> _pages = [
    const _HomePage(),
    const SizedBox(), // Placeholder for scan (handled by button)
    const DepartmentSelectionScreen(), // History shows department databases
  ];

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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CameraScreen(idType: 'senior'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _selectedIndex == 1 ? const SizedBox() : _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(),
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
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildBannerSection(),
            _buildContentSection(),
            _buildInfoCards(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Image.asset(
            'assets/images/idetect_logo.png',
            height: 85,
            fit: BoxFit.contain,
          ),
          // Profile icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: const Icon(Icons.person_outline, color: Colors.grey),
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
        child: Stack(
          children: [
            // Banner image placeholder
            Container(
              height: 180,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: Image.asset(
                'assets/images/valid_banner.jpg',
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
          ],
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
            'LOREM IPSUM',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Quisque dictus scelerisque efficitur. Aenean venenatis ultricies purus turpis. Nullam sodales, arcu nec dapibus semper, quam laoreet dui, eu suscipit quam laoreet vel. Donec vitae turpis at ullamcorper erat sagittis in. Morbi vestibulum dictum nunc eget varius magna. Vivamus magna tellus. Aenean odio urna, scelerisque ut lacinia ac. Condimentum id purus. Proin non consequat. Nunc condimentum sodales ultrices purus turpis turpis. Do nec justo, accumsan et, pharetra lacinia dignissim enim. Nunc at massa auctor, porta arcu ac, lacinia sit amet. Sed eu placerat finibus tellus sed.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
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
