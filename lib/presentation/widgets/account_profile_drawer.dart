// NOTE: avatar photo is currently held only in local widget state
// (picked via image_picker, same pattern as the camera screen's
// _pickFromGallery). There's no upload-to-server call here yet since
// I don't have the ApiService method for it — wire _pickAvatar's
// TODO into whatever endpoint persists the establishment account's
// photo, then load the persisted URL into the CircleAvatar instead
// of (or alongside) the local File.
//
// Change Password currently routes to a placeholder — swap
// ChangePasswordPlaceholderScreen for the real screen once it exists.
//
// Fonts assume google_fonts is already added (per the login screen
// redesign) — Source Serif 4 for the name, IBM Plex Mono for email/
// section labels/version line, matching the rest of the app.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/change_password_screen.dart';

class AccountProfileDrawer extends StatefulWidget {
  const AccountProfileDrawer({super.key, this.user});

  final Map<String, dynamic>? user;

  @override
  State<AccountProfileDrawer> createState() => _AccountProfileDrawerState();
}

class _AccountProfileDrawerState extends State<AccountProfileDrawer> {
  static const _institutional = Color(0xFF002E6B);
  static const _fieldFill = Color(0xFFF6F8FB);
  static const _fieldBorder = Color(0xFFE3E7EE);

  File? _avatarFile;
  bool _pickingAvatar = false;

  String _safeValue(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null) return; // user cancelled the picker

      setState(() {
        _pickingAvatar = true;
        _avatarFile = File(picked.path);
      });

      // TODO: upload _avatarFile to the server here (ApiService call),
      // then update the persisted user record with the returned URL.
      // Currently the new photo only lives in local widget state and
      // will not survive app restart or reflect on other screens
      // until that call exists.

      setState(() => _pickingAvatar = false);
    } catch (e) {
      setState(() => _pickingAvatar = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await ApiService.logout();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openChangePassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceUser = widget.user ?? ApiService.currentUser;

    final fullName = _safeValue(
      sourceUser?['name']?.toString() ?? sourceUser?['full_name']?.toString(),
      'Account User',
    );
    final email =
        _safeValue(sourceUser?['email']?.toString(), 'No email available');
    final role = _safeValue(
      sourceUser?['role']?.toString() ?? sourceUser?['user_type']?.toString(),
      'Establishment Account',
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: identity ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              color: _institutional,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!)
                            : null,
                        child: _avatarFile == null
                            ? const Icon(
                                Icons.person,
                                size: 32,
                                color: _institutional,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: GestureDetector(
                          onTap: _pickingAvatar ? null : _pickAvatar,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: _institutional, width: 1.5),
                            ),
                            child: _pickingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _institutional,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: _institutional,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    fullName,
                    style: GoogleFonts.sourceSerif4(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: GoogleFonts.ibmPlexMono(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // ── Role badge ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _fieldBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined,
                        color: _institutional, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: _institutional,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Account actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'ACCOUNT',
                style: GoogleFonts.ibmPlexMono(
                  color: Colors.black38,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _ActionRow(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              onTap: () => _openChangePassword(context),
            ),

            const Spacer(),

            // ── Footer: version + log out ──
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Center(
                child: Text(
                  'iDetect · Establishment Portal',
                  style: GoogleFonts.ibmPlexMono(
                    color: Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _institutional,
                    side: const BorderSide(color: _fieldBorder, width: 1),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat, ledger-style tappable row used for account actions.
/// Add more `_ActionRow`s under the same "ACCOUNT" section if
/// additional account-management items come up later.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF355C9A)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
