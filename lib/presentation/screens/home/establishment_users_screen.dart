import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class EstablishmentUsersScreen extends StatefulWidget {
  const EstablishmentUsersScreen({super.key});

  @override
  State<EstablishmentUsersScreen> createState() =>
      _EstablishmentUsersScreenState();
}

class _EstablishmentUsersScreenState extends State<EstablishmentUsersScreen> {
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
      password: result['password'] as String,
    );
    if (!mounted) return;
    if (response['error'] != null) {
      _showMessage(response['error'].toString());
    } else {
      _showMessage('Regular User created.');
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
      appBar: AppBar(
        title: const Text('Establishment Users'),
        actions: [
          IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add user'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final user = _users[index];
                            final active = user['account_status'] == 'active';
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                      active ? Icons.person : Icons.person_off),
                                ),
                                title:
                                    Text(user['full_name']?.toString() ?? ''),
                                subtitle: Text(
                                  '${user['email']}\n${user['role'] == 'establishment_super_user' ? 'Super User' : 'Regular User'} · ${user['account_status']}',
                                ),
                                isThreeLine: true,
                                trailing:
                                    user['id'] == ApiService.currentUser?['id']
                                        ? const Chip(label: Text('You'))
                                        : PopupMenuButton<String>(
                                            onSelected: (action) {
                                              if (action == 'status') {
                                                _toggleStatus(user);
                                              } else if (action == 'password') {
                                                _resetPassword(user);
                                              } else if (action == 'role') {
                                                _changeRole(user);
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

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add Regular User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name')),
              TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email')),
              TextField(
                controller: _password,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Temporary password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().isEmpty ||
                  _email.text.trim().isEmpty ||
                  _password.text.length < 8) {
                return;
              }
              Navigator.pop(context, {
                'full_name': _name.text.trim(),
                'email': _email.text.trim(),
                'password': _password.text,
              });
            },
            child: const Text('Create'),
          ),
        ],
      );
}
