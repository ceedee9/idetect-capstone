import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/constants/app_design_system.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../services/session_timeout_service.dart';
import 'login_screen.dart';
import 'status_screen.dart';
import 'transactions_screen.dart';
import 'disputes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<RemoteMessage>? _fcmSub;

  final List<Widget> _pages = const [
    StatusScreen(),
    TransactionsScreen(),
    DisputesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fcmSub = FcmService.foregroundMessages.listen(_onForegroundMessage);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    if (!mounted) return;
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

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ApiService.clearToken();
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final fullName = user?['full_name'] ?? 'Beneficiary';

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
                user?['beneficiary_type']
                        ?.toString()
                        .replaceAll('_', ' ')
                        .replaceFirstMapped(
                          RegExp(r'^\w'),
                          (m) => m[0]!.toUpperCase(),
                        ) ??
                    '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            Semantics(
              label: 'Sign out',
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: _logout,
                tooltip: 'Sign Out',
                padding: const EdgeInsets.all(12),
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
                    label: 'Status',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    label: 'History',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.gavel_outlined,
                    activeIcon: Icons.gavel_rounded,
                    label: 'Disputes',
                    index: 2,
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
  }) {
    final isSelected = _selectedIndex == index;
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
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: AppDesignSystem.navIconSize,
                    color: isSelected
                        ? AppDesignSystem.primaryBlue
                        : AppDesignSystem.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
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
