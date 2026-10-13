import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';
import '../../services/backend_api_service.dart';

const _roles = ['security', 'librarian', 'driver'];
const _roleLabels = {'security': 'Security Staff', 'librarian': 'Librarian', 'driver': 'Driver'};

class AdminAccountsScreen extends StatelessWidget {
  const AdminAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _roles.length,
      child: Column(
        children: [
          const Material(
            color: AppColors.cardBackground,
            child: TabBar(
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: AppColors.bodyText,
              indicatorColor: AppColors.primaryBlue,
              tabs: [Tab(text: 'Security'), Tab(text: 'Librarian'), Tab(text: 'Driver')],
            ),
          ),
          Expanded(
            child: TabBarView(children: _roles.map((r) => _RoleAccountsTab(role: r)).toList()),
          ),
        ],
      ),
    );
  }
}

class _RoleAccountsTab extends ConsumerWidget {
  final String role;
  const _RoleAccountsTab({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsByRoleProvider(role));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => _AddAccountDialog(role: role)),
        icon: const Icon(Icons.person_add_alt),
        label: Text('Add ${_roleLabels[role]}'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load accounts.\n$err')),
        data: (accounts) => accounts.isEmpty
            ? Center(child: Text('No ${_roleLabels[role]} accounts yet.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _AccountTile(account: accounts[i], role: role),
              ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  final AccountSummary account;
  final String role;
  const _AccountTile({required this.account, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: account.active ? AppColors.accentLightBlue : AppColors.divider,
          child: Icon(Icons.person_outline, color: account.active ? AppColors.primaryBlueDark : AppColors.bodyText),
        ),
        title: Text(account.name),
        subtitle: Text(account.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit / reset password',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => showDialog(context: context, builder: (_) => _EditStaffDialog(account: account, role: role)),
            ),
            TextButton(
              onPressed: () async {
                if (account.active) {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Deactivate this account?',
                    message: '${account.name} will lose access to SecureCampus immediately.',
                    confirmLabel: 'Deactivate',
                  );
                  if (!confirmed) return;
                }
                await ref.read(adminRepositoryProvider).setAccountActive(account.uid, !account.active);
              },
              child: Text(
                account.active ? 'Deactivate' : 'Activate',
                style: TextStyle(color: account.active ? AppColors.error : AppColors.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditStaffDialog extends ConsumerStatefulWidget {
  final AccountSummary account;
  final String role;
  const _EditStaffDialog({required this.account, required this.role});

  @override
  ConsumerState<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends ConsumerState<_EditStaffDialog> {
  late final TextEditingController _name;
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.account.name);
  }

  Future<void> _submit() async {
    final nameChanged = _name.text.trim() != widget.account.name && _name.text.trim().isNotEmpty;
    final newPassword = _password.text.trim();
    if (!nameChanged && newPassword.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (newPassword.isNotEmpty && newPassword.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(backendApiServiceProvider).updateAccount(
            uid: widget.account.uid,
            role: widget.role,
            name: nameChanged ? _name.text.trim() : null,
            password: newPassword.isEmpty ? null : newPassword,
          );
      if (!mounted) return;
      if (newPassword.isNotEmpty) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Password reset'),
            content: SelectableText(
              'New password for ${widget.account.email}: $newPassword\n\nShare this with them securely.',
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } on BackendApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.account.name}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              decoration: const InputDecoration(
                labelText: 'New password (optional)',
                helperText: 'Leave blank to keep the current password.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }
}

class _AddAccountDialog extends ConsumerStatefulWidget {
  final String role;
  const _AddAccountDialog({required this.role});

  @override
  ConsumerState<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<_AddAccountDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'Enter a valid name and email.');
      return;
    }
    final chosenPassword = _password.text.trim();
    if (chosenPassword.isNotEmpty && chosenPassword.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters (or leave blank for a random one).');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(backendApiServiceProvider).createAccount(
            email: _email.text.trim(),
            name: _name.text.trim(),
            role: widget.role,
            password: chosenPassword.isEmpty ? null : chosenPassword,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Account created'),
          content: SelectableText(
            'Email: ${result['email']}\nPassword: ${result['temporaryPassword']}\n\n'
            'Share this with them securely.',
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
        ),
      );
    } on BackendApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${_roleLabels[widget.role]}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              decoration: const InputDecoration(
                labelText: 'Password (optional)',
                helperText: 'Leave blank to auto-generate a random one instead.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}