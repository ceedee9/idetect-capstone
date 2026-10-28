// =============================================================================
// FILE: lib/presentation/screens/home/home_screen_redesigned.dart
// PURPOSE: New home screen based on design mockup
// FEATURES: Logo header, banner section, info cards, bottom navigation
// =============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_design_system.dart';
import '../../widgets/account_profile_drawer.dart';
import '../../widgets/account_change_banner.dart';
import '../../widgets/bplo_contact_card.dart';
import 'info_detail_screen.dart';
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
        shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.cardRadius),
        title: Text(
          'Select ID Type',
          style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: AppDesignSystem.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'What type of ID are you scanning?',
              style: AppDesignSystem.bodyMedium
                  .copyWith(color: AppDesignSystem.textSecondary),
            ),
            SizedBox(height: AppDesignSystem.spaceMD),
            // Senior Citizen ID button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showSeniorFormatDialog();
                },
                icon: const Icon(Icons.elderly, size: 26),
                label: const Text('Senior Citizen ID'),
                style: AppDesignSystem.primaryButton,
              ),
            ),
            SizedBox(height: AppDesignSystem.spaceXS),
            // PWD ID button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showPWDFormatDialog();
                },
                icon: const Icon(Icons.accessible, size: 26),
                label: const Text('PWD ID'),
                style: AppDesignSystem.primaryButton,
              ),
            ),
            SizedBox(height: AppDesignSystem.spaceXS),
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
                icon: const Icon(Icons.auto_awesome, size: 24),
                style: AppDesignSystem.secondaryButton,
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
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
            child: Text('Cancel',
                style: AppDesignSystem.bodyMedium
                    .copyWith(color: AppDesignSystem.textSecondary)),
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
        shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.cardRadius),
        title: Text(
          'Which ID format?',
          style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: AppDesignSystem.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check for a round holographic seal near the signature.',
              style: AppDesignSystem.bodyMedium
                  .copyWith(color: AppDesignSystem.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Has seal, labeled "ID No." → New\nNo seal, labeled "Control No." → Old',
              style: AppDesignSystem.bodySmall
                  .copyWith(color: AppDesignSystem.textTertiary, height: 1.4),
            ),
            SizedBox(height: AppDesignSystem.spaceMD),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _onSeniorFormatSelected('old');
                },
                icon: const Icon(Icons.badge_outlined, size: 24),
                label: const Text('Old format'),
                style: AppDesignSystem.primaryButton,
              ),
            ),
            SizedBox(height: AppDesignSystem.spaceXS),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _onSeniorFormatSelected('new');
                },
                icon: const Icon(Icons.verified_outlined, size: 24),
                label: const Text('New format (with seal)'),
                style: AppDesignSystem.primaryButton,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: AppDesignSystem.bodyMedium
                    .copyWith(color: AppDesignSystem.textSecondary)),
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

  /// Ask which PWD ID format was presented — old, or new (with holographic
  /// seal). Unlike Senior's redesign, PWD's label text didn't change
  /// ("ID No." is used on both formats) — the seal itself is the only
  /// visual difference staff need to look for.
  void _showPWDFormatDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.cardRadius),
        title: Text(
          'Which ID format?',
          style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: AppDesignSystem.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check for a round holographic seal near the ID number.',
              style: AppDesignSystem.bodyMedium
                  .copyWith(color: AppDesignSystem.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Has seal → New\nNo seal → Old (still valid)',
              style: AppDesignSystem.bodySmall
                  .copyWith(color: AppDesignSystem.textTertiary, height: 1.4),
            ),
            SizedBox(height: AppDesignSystem.spaceMD),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _onPWDFormatSelected('old');
                },
                icon: const Icon(Icons.badge_outlined, size: 24),
                label: const Text('Old format'),
                style: AppDesignSystem.primaryButton,
              ),
            ),
            SizedBox(height: AppDesignSystem.spaceXS),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _onPWDFormatSelected('new');
                },
                icon: const Icon(Icons.verified_outlined, size: 24),
                label: const Text('New format (with seal)'),
                style: AppDesignSystem.primaryButton,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: AppDesignSystem.bodyMedium
                    .copyWith(color: AppDesignSystem.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _onPWDFormatSelected(String format) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(idType: 'pwd', idFormat: format),
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
        backgroundColor: AppDesignSystem.backgroundLight,
        endDrawer: const AccountProfileDrawer(),
        body: _selectedIndex == 1 ? const SizedBox() : pages[_selectedIndex],
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        border: const Border(
          top: BorderSide(color: AppDesignSystem.borderLight),
        ),
        boxShadow: AppDesignSystem.shadowSM,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                icon: Icons.history_rounded,
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
    final color =
        isSelected ? AppDesignSystem.primaryBlue : AppDesignSystem.textTertiary;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 10,
                letterSpacing: 1.0,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: InkWell(
        onTap: () => _onItemTapped(1),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppDesignSystem.primaryBlue,
            shape: BoxShape.circle,
            border:
                Border.all(color: AppDesignSystem.backgroundWhite, width: 3),
            boxShadow: AppDesignSystem.shadowMD,
          ),
          child: const Icon(
            Icons.credit_card_rounded,
            color: Colors.white,
            size: 26,
          ),
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
            const AccountChangeBanner(),
            _buildBannerSection(),
            _buildContentSection(),
            _buildCampaignImageSection(),
            _buildInfoCards(context),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.spaceMD),
              child: BploContactCard(),
            ),
            SizedBox(height: AppDesignSystem.spaceMD),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spaceMD,
          vertical: AppDesignSystem.spaceSM),
      decoration: const BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        border: Border(bottom: BorderSide(color: AppDesignSystem.borderLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Image.asset(
            'assets/images/idetect_logo.png',
            height: 48,
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
                color: AppDesignSystem.backgroundLightBlue,
                border:
                    Border.all(color: AppDesignSystem.borderLight, width: 1.5),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: AppDesignSystem.primaryBlue, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSection() {
    return Container(
      margin: EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowMD,
      ),
      child: ClipRRect(
        borderRadius: AppDesignSystem.cardRadius,
        child: Container(
          height: 400,
          width: double.infinity,
          color: AppDesignSystem.backgroundLight,
          child: Image.asset(
            'assets/images/campaign_1.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppDesignSystem.backgroundLightBlue,
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 60,
                    color: AppDesignSystem.iconLight,
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
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        boxShadow: AppDesignSystem.shadowSM,
        border: Border.all(color: AppDesignSystem.borderLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        child: Container(
          height: 280,
          width: double.infinity,
          color: AppDesignSystem.backgroundWhite,
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppDesignSystem.backgroundLightBlue,
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 60,
                    color: AppDesignSystem.iconLight,
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
      padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OUR MANDATE',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Know Your Benefits and Protect Your Community',
            style: GoogleFonts.sourceSerif4(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          Text(
            'iDetect supports the City of Valenzuela in promoting legitimate identification, proper benefit access, and respect for the rights of senior citizens and persons with disability (PWD).',
            style: AppDesignSystem.bodyMedium
                .copyWith(color: AppDesignSystem.textSecondary),
          ),
          SizedBox(height: AppDesignSystem.spaceMD),
          _buildPolicyCard(
            title: 'Republic Act 9994',
            subtitle: 'Expanded Senior Citizens Act of 2010',
            description:
                'Provides additional benefits and privileges for qualified senior citizens, including discounts and social support measures. Proper ID validation helps ensure these benefits reach the rightful recipients.',
          ),
          SizedBox(height: AppDesignSystem.spaceXS),
          _buildPolicyCard(
            title: 'Republic Act 10754',
            subtitle:
                'An Act Expanding the Benefits and Privileges of Persons with Disability',
            description:
                'Strengthens and expands mandatory privileges for persons with disability, including discounts and VAT exemptions. Accurate PWD ID verification protects both establishments and legitimate beneficiaries.',
          ),
          SizedBox(height: AppDesignSystem.spaceXS),
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
    final accent =
        isCampaign ? AppDesignSystem.accentRed : AppDesignSystem.primaryBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
        border: Border(left: BorderSide(color: accent, width: 3)),
        boxShadow: AppDesignSystem.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sourceSerif4(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle.toUpperCase(),
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: accent,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppDesignSystem.bodySmall
                .copyWith(color: AppDesignSystem.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppDesignSystem.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESOURCES',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.textTertiary,
            ),
          ),
          SizedBox(height: AppDesignSystem.spaceSM),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'assets/images/poster_senior_pwd.jpg',
                  'New Senior Citizen & PWD ID Design',
                  () => _openInfoDetail(
                    context,
                    imagePath: 'assets/images/poster_senior_pwd.jpg',
                    title: 'New Senior Citizen & PWD ID Design',
                    body:
                        'Starting 2025, the City of Valenzuela began issuing a '
                        'redesigned Senior Citizen ID featuring a round '
                        'holographic seal near the signature/thumbmark, and a '
                        'field labeled "ID No." instead of "Control No."\n\n'
                        'IDs issued before the redesign remain fully valid — '
                        'the absence of a seal does not mean an ID is fake. '
                        'When scanning, check for the seal: its presence '
                        'indicates the new format, its absence simply means '
                        'an older, still-valid design.',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'assets/images/counter_display.jpg',
                  'VAL ID Validation at Establishments',
                  () => _openInfoDetail(
                    context,
                    imagePath: 'assets/images/counter_display.jpg',
                    title: 'VAL ID Validation at Establishments',
                    body: 'The City of Valenzuela operates the VAL ID portal, '
                        'letting establishment staff manually confirm a Senior '
                        'Citizen or PWD ID number against official records. '
                        'iDetect complements this by automating ID capture and '
                        'verification directly within your establishment\'s '
                        'workflow, while keeping a full audit trail of every '
                        'scan.',
                    externalUrl: 'https://valid.valenzuela.gov.ph',
                    externalUrlLabel: 'Visit VAL ID portal',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'assets/images/poster_person1.jpg',
                  'Verify Senior & PWD IDs Online',
                  () => _openInfoDetail(
                    context,
                    imagePath: 'assets/images/poster_person1.jpg',
                    title: 'Verify Senior & PWD IDs Online',
                    body: 'Senior citizens, PWD cardholders, and the general '
                        'public can look up an ID\'s status through the '
                        'city\'s official VAL ID portal — helping confirm '
                        'legitimacy before a discount or benefit is granted.',
                    externalUrl: 'https://valid.valenzuela.gov.ph',
                    externalUrlLabel: 'Visit VAL ID portal',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'assets/images/poster_person2.jpg',
                  'Establishments Display Validation Info',
                  () => _openInfoDetail(
                    context,
                    imagePath: 'assets/images/poster_person2.jpg',
                    title: 'Establishments Display Validation Info',
                    body: 'Establishments are encouraged to display validation '
                        'reference materials — such as the current and '
                        'previous Senior Citizen and PWD ID formats — at the '
                        'counter, so staff and customers can quickly recognize '
                        'a valid ID on sight, alongside using iDetect for '
                        'scan-based verification.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openInfoDetail(
    BuildContext context, {
    required String imagePath,
    required String title,
    required String body,
    String? externalUrl,
    String? externalUrlLabel,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoDetailScreen(
          imagePath: imagePath,
          title: title,
          body: body,
          externalUrl: externalUrl,
          externalUrlLabel: externalUrlLabel,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String imagePath, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
      child: Container(
        decoration: BoxDecoration(
          color: AppDesignSystem.backgroundWhite,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          border: Border.all(color: AppDesignSystem.borderLight),
          boxShadow: AppDesignSystem.shadowSM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDesignSystem.radiusMD)),
              child: Container(
                height: 100,
                width: double.infinity,
                color: AppDesignSystem.backgroundLight,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppDesignSystem.backgroundLightBlue,
                      child: Icon(Icons.image_outlined,
                          color: AppDesignSystem.iconLight),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(AppDesignSystem.spaceSM),
              decoration: const BoxDecoration(
                color: AppDesignSystem.primaryBlue,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppDesignSystem.radiusMD)),
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
                      color: AppDesignSystem.accentRed,
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.radiusXS),
                    ),
                    child: Text(
                      'Read More →',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
