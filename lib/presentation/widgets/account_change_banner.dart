// =============================================================================
// FILE: lib/presentation/widgets/account_change_banner.dart
// PURPOSE: Shows recent changes to the signed-in establishment user's account
//          (role, activation, password reset) as a dismissible banner.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';

const _dismissedKey = 'dismissed_account_change_ids';

class AccountChangeBanner extends StatefulWidget {
  const AccountChangeBanner({super.key});

  @override
  State<AccountChangeBanner> createState() => _AccountChangeBannerState();
}

class _AccountChangeBannerState extends State<AccountChangeBanner> {
  List<Map<String, dynamic>> _changes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await ApiService.getMyAccountChanges();
    if (!mounted || response['error'] != null) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissed = (prefs.getStringList(_dismissedKey) ?? []).toSet();
    final raw = (response['changes'] as List?) ?? [];
    final visible = raw
        .cast<Map<String, dynamic>>()
        .where((c) => !dismissed.contains(c['id'].toString()))
        .toList();

    if (mounted) setState(() => _changes = visible);
  }

  Future<void> _dismiss(Map<String, dynamic> change) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_dismissedKey) ?? [];
    final id = change['id'].toString();
    if (!dismissed.contains(id)) {
      dismissed.add(id);
      await prefs.setStringList(_dismissedKey, dismissed);
    }
    if (mounted) setState(() => _changes.remove(change));
  }

  String _message(String action) {
    switch (action) {
      case 'establishment_user_role_changed':
        return 'Your account role was changed by an administrator.';
      case 'establishment_user_password_reset':
        return 'Your password was reset by an administrator.';
      case 'establishment_user_activated':
        return 'Your account was activated.';
      case 'establishment_user_deactivated':
        return 'Your account was deactivated.';
      default:
        return 'Your account was updated.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_changes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: _changes.map((change) {
          final when = DateTime.tryParse(change['created_at']?.toString() ?? '');
          final date = when == null
              ? ''
              : '${when.toLocal().day}/${when.toLocal().month}/${when.toLocal().year}';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: theme.colorScheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _message(change['action']?.toString() ?? ''),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (date.isNotEmpty)
                        Text(
                          date,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: Icon(Icons.close,
                      color: theme.colorScheme.onPrimaryContainer),
                  onPressed: () => _dismiss(change),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
