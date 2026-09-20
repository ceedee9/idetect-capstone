import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_design_system.dart';
import '../core/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../services/session_timeout_service.dart';
import 'login_screen.dart';
import 'status_screen.dart';
import 'transactions_screen.dart';
import 'disputes_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _unreadCount = 0;
  StreamSubscription<RemoteMessage>? _fcmSub;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const StatusScreen(),
      const TransactionsScreen(),
      const DisputesScreen(),
      NotificationsScreen(onReadChanged: _fetchUnreadCount),
    ];
    _fcmSub = FcmService.foregroundMessages.listen(_onForegroundMessage);
    _fetchUnreadCount();
  }

  void _onForegroundMessage(RemoteMessage message) {
    final loc = AppLocalizations.of(context)!;
    final title = message.notification?.title ?? loc.notificationFallbackTitle;
    final body = message.notification?.body ?? '';
    if (!mounted) return;
    setState(() => _unreadCount++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (body.isNotEmpty)
              Text(body, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        backgroundColor: AppDesignSystem.primaryBlue,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _fetchUnreadCount() async {
    final count = await ApiService.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  /// Maps the raw API beneficiary_type value ('senior_citizen' | 'pwd')
  /// to its localized display label. Falls back to an empty string for
  /// any unrecognized/null value, matching the previous behavior.
  String _beneficiaryTypeLabel(dynamic rawType, AppLocalizations loc) {
    switch (rawType?.toString()) {
      case 'senior_citizen':
        return loc.beneficiaryTypeSenior;
      case 'pwd':
        return loc.beneficiaryTypePwd;
      default:
        return '';
    }
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    if (index == 3) _fetchUnreadCount();
  }

  void _logout() {
    final loc = AppLocalizations.of(context)!;
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // Matches the shape/text-sizing convention already established
        // on the login screen's dialogs, rather than bare AlertDialog
        // defaults (which are noticeably smaller than this app's
        // accessibility-sized body text elsewhere).
        shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.cardRadius),
        title: Text(loc.homeSignOut, style: const TextStyle(fontSize: 20)),
        content: Text(
          loc.homeSignOutConfirm,
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.commonCancel, style: const TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.accentRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              // Heavier than the selection-click above — this is the
              // consequential, harder-to-undo action in this dialog.
              HapticFeedback.mediumImpact();
              ApiService.clearToken();
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: Text(
              loc.homeSignOut,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();
    final isEnglish = localeProvider.locale.languageCode == 'en';
    final user = ApiService.currentUser;
    final fullName = user?['full_name'] ?? loc.appBeneficiaryFallback;

    return SessionActivityWrapper(
      child: Scaffold(
        backgroundColor: AppDesignSystem.backgroundWarm,
        appBar: AppBar(
          backgroundColor: AppDesignSystem.primaryBlue,
          elevation: 0,
          toolbarHeight: 64,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                _beneficiaryTypeLabel(user?['beneficiary_type'], loc),
                // Was 14sp — below this design system's own stated 15sp
                // caption floor (same violation already fixed on the
                // login screen's mobile-format hint).
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            Semantics(
              label: loc.languageToggleTooltip,
              button: true,
              child: Tooltip(
                message: loc.languageToggleTooltip,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.read<LocaleProvider>().setLocale(
                      isEnglish ? const Locale('fil') : const Locale('en'),
                    );
                  },
                  style: TextButton.styleFrom(
                    // Height was 48 — under this system's own 56dp
                    // touchTargetMin. Width already met it.
                    minimumSize: const Size(56, 56),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    // Shows the language you'll SWITCH TO, not the current one —
                    // matches how language toggles conventionally read (e.g. "中文" on an English UI).
                    isEnglish ? 'FIL' : 'EN',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              label: loc.homeSignOut,
              button: true,
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: _logout,
                tooltip: loc.homeSignOut,
                // 12 gave a ~50dp tap area (12*2 + 26 icon) — under the
                // 56dp touchTargetMin. 15 brings it to the full 56dp.
                padding: const EdgeInsets.all(15),
              ),
            ),
          ],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: AppDesignSystem.navBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.badge_outlined,
                    activeIcon: Icons.badge_rounded,
                    label: loc.navStatus,
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    label: loc.navHistory,
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.gavel_outlined,
                    activeIcon: Icons.gavel_rounded,
                    label: loc.navDisputes,
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications_rounded,
                    label: loc.navAlerts,
                    index: 3,
                    badgeCount: _unreadCount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ), // Scaffold
    ); // SessionActivityWrapper
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;
    final iconWidget = Icon(
      isSelected ? activeIcon : icon,
      size: AppDesignSystem.navIconSize,
      color: isSelected
          ? AppDesignSystem.primaryBlue
          : AppDesignSystem.textSecondary,
    );
    return Expanded(
      child: Semantics(
        label: label,
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          splashColor: AppDesignSystem.primaryBlue.withOpacity(0.08),
          highlightColor: AppDesignSystem.primaryBlue.withOpacity(0.05),
          child: SizedBox(
            height: AppDesignSystem.navBarHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppDesignSystem.animationFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppDesignSystem.primaryBlue.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: badgeCount > 0
                      ? Badge.count(count: badgeCount, child: iconWidget)
                      : iconWidget,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  // Was 13sp — below this design system's own stated
                  // 15sp caption floor.
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppDesignSystem.primaryBlue
                        : AppDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
