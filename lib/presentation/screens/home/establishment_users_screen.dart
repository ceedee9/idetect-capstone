import 'package:flutter/material.dart';
import '../../../core/constants/app_design_system.dart';
import '../../../services/api_service.dart';

class EstablishmentUsersScreen extends StatefulWidget {
  const EstablishmentUsersScreen({super.key});

  @override
  State<EstablishmentUsersScreen> createState() =>
      _EstablishmentUsersScreenState();
}

class _EstablishmentUsersScreenState extends State<EstablishmentUsersScreen> {
  static const _navy = AppDesignSystem.primaryBlue;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  bool get _isSuperUser =>
      ApiService.currentUser?['role'] == 'establishment_super_user';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final result = await ApiService.getEstablishmentUsers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result['error']?.toString();
      _users = (result['users'] as List?)
              ?.map((user) => Map<String, dynamic>.from(user as Map))
              .toList() ??
          [];
    });
  }

  Future<void> _createUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );
    if (result == null) return;
    final response = await ApiService.createEstablishmentUser(
      email: result['email'] as String,
      fullName: result['full_name'] as String,
    );
    if (!mounted) return;
    if (response['error'] != null) {
      _showMessage(response['error'].toString());
    } else {
      _showMessage('Invitation sent to the Regular User.');
      _loadUsers();
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    final next = user['account_status'] == 'active' ? 'inactive' : 'active';
    final response = await ApiService.updateEstablishmentUserStatus(
      user['id'].toString(),
      next,
    );
    if (!mounted) return;
    if (response['error'] != null) {
      _showMessage(response['error'].toString());
    } else {
      _loadUsers();
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New temporary password',
            helperText: 'At least 8 characters',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length >= 8) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null) return;
    final response = await ApiService.resetEstablishmentUserPassword(
      user['id'].toString(),
      password,
    );
    if (!mounted) return;
    _showMessage(
        response['error']?.toString() ?? 'Password reset successfully.');
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final nextRole = user['role'] == 'establishment_super_user'
        ? 'establishment_regular_user'
        : 'establishment_super_user';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change role?'),
        content: Text(
          'Change ${user['full_name']} to ${nextRole == 'establishment_super_user' ? 'Super User' : 'Regular User'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change role'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final response = await ApiService.updateEstablishmentUserRole(
      user['id'].toString(),
      nextRole,
    );
    if (!mounted) return;
    if (response['error'] != null) {
      _showMessage(response['error'].toString());
    } else {
      _showMessage('Role updated.');
      _loadUsers();
    }
  }

  Future<void> _resendInvitation(Map<String, dynamic> user) async {
    final response = await ApiService.resendEstablishmentUserInvitation(
      user['id'].toString(),
    );
    if (!mounted) return;
    _showMessage(
      response['error']?.toString() ?? 'Invitation resent successfully.',
    );
    if (response['error'] == null) _loadUsers();
  }

  Future<void> _revokeInvitation(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke invitation?'),
        content: Text(
          'This will permanently invalidate the invitation link for ${user['full_name']}. They will not be able to use it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revoke invitation'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final response = await ApiService.revokeEstablishmentUserInvitation(
      user['id'].toString(),
    );
    if (!mounted) return;
    _showMessage(response['error']?.toString() ?? 'Invitation revoked.');
    if (response['error'] == null) _loadUsers();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Establishment Users')),
        body: const Center(
            child:
                Text('Only the establishment Super User can manage accounts.')),
      );
    }
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Manage Users',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            tooltip: 'Refresh users',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Regular User'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _navy),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadUsers)
              : RefreshIndicator(
                  color: _navy,
                  onRefresh: _loadUsers,
                  child: _users.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 180),
                            Center(
                                child: Text('No establishment users found.')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final user = _users[index];
                            final active = user['account_status'] == 'active';
                            final isCurrentUser =
                                user['id'] == ApiService.currentUser?['id'];
                            final isSuperUser =
                                user['role'] == 'establishment_super_user';
                            final invitationStatus =
                                user['invitation_status']?.toString();
                            final invitationPending =
                                invitationStatus == 'pending' ||
                                    invitationStatus == 'expired';
                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: AppDesignSystem.borderLight,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: active
                                      ? _navy.withValues(alpha: 0.10)
                                      : AppDesignSystem.backgroundLight,
                                  foregroundColor: active
                                      ? _navy
                                      : AppDesignSystem.textTertiary,
                                  child: Icon(
                                    active
                                        ? Icons.person_outline_rounded
                                        : Icons.person_off_outlined,
                                  ),
                                ),
                                title: Text(
                                  user['full_name']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: AppDesignSystem.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${user['email']}\n${isSuperUser ? 'Super User' : 'Regular User'} · ${user['account_status']}${invitationStatus == null ? '' : ' · Invitation: $invitationStatus'}',
                                    style: const TextStyle(
                                      color: AppDesignSystem.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: isCurrentUser
                                    ? const Chip(
                                        label: Text('You'),
                                        labelStyle: TextStyle(color: _navy),
                                        backgroundColor:
                                            AppDesignSystem.backgroundLightBlue,
                                      )
                                    : PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_vert_rounded,
                                          color: _navy,
                                        ),
                                        onSelected: (action) {
                                          if (action == 'status') {
                                            _toggleStatus(user);
                                          } else if (action == 'password') {
                                            _resetPassword(user);
                                          } else if (action == 'role') {
                                            _changeRole(user);
                                          } else if (action == 'resend') {
                                            _resendInvitation(user);
                                          } else if (action == 'revoke') {
                                            _revokeInvitation(user);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (user['role'] ==
                                              'establishment_regular_user')
                                            PopupMenuItem(
                                              value: 'status',
                                              child: Text(
                                                active
                                                    ? 'Deactivate'
                                                    : 'Activate',
                                              ),
                                            ),
                                          if (invitationPending)
                                            const PopupMenuItem(
                                              value: 'resend',
                                              child: Text('Resend invitation'),
                                            ),
                                          if (user['invitation_status'] ==
                                              'pending')
                                            const PopupMenuItem(
                                              value: 'revoke',
                                              child: Text('Revoke invitation'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'password',
                                            child: Text('Reset password'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'role',
                                            child: Text('Change role'),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppDesignSystem.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppDesignSystem.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppDesignSystem.primaryBlue,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Add Regular User',
          style: TextStyle(
            color: AppDesignSystem.primaryBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  )),
              TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  )),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  'The user will receive an email invitation and create their own password. The invitation expires in 24 hours.',
                  style: TextStyle(
                    color: AppDesignSystem.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignSystem.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context, {
                'full_name': _name.text.trim(),
                'email': _email.text.trim(),
              });
            },
            child: const Text('Create'),
          ),
        ],
      );
}
