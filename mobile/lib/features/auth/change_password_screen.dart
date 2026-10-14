import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/password_gate.dart';
import '../../core/router/role_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/password_policy.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_providers.dart';
import '../../services/auth_service.dart';

/// Change your own password.
///
/// Two uses: *forced* on first login (the account was created with a temporary
/// password, so there is no way out except choosing a new one or signing out),
/// and *voluntary* from the menu (Back works as normal).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPasswords = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _forced {
    final user = ref.read(currentAppUserProvider).valueOrNull;
    return user != null &&
        passwordChangeEnforced &&
        user.mustResetPassword &&
        !ref.read(passwordChangedThisSessionProvider);
  }

  Future<void> _submit() async {
    final user = ref.read(currentAppUserProvider).valueOrNull;
    if (user == null) return;

    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter your current (temporary) password.');
      return;
    }
    final problem = validateNewPassword(
      newPassword: _new.text,
      confirm: _confirm.text,
      current: _current.text,
      registrationNumber: ref.read(studentProfileProvider).valueOrNull?.registrationNumber,
      email: user.email,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final wasForced = _forced;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).changePassword(currentPassword: _current.text, newPassword: _new.text);
      ref.read(passwordChangedThisSessionProvider.notifier).state = true;

      // Clear the "must change" flag. If Firestore refuses (rules not published
      // yet) the password is still changed; the session flag above keeps the
      // screen from coming back until the next sign-in.
      try {
        await ref.read(userRepositoryProvider).clearMustResetPassword(user.uid);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
      if (wasForced) {
        context.go(homePathForRole(user.role));
      } else if (context.canPop()) {
        context.pop();
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not change the password. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch (not read) so the screen switches to "first login" mode as soon as
    // the signed-in user's profile has loaded
    final user = ref.watch(currentAppUserProvider).valueOrNull;
    final forced = user != null &&
        passwordChangeEnforced &&
        user.mustResetPassword &&
        !ref.watch(passwordChangedThisSessionProvider);

    return PopScope(
      canPop: !forced,
      child: Scaffold(
        appBar: AppBar(
          title: Text(forced ? 'Choose your password' : 'Change password'),
          automaticallyImplyLeading: !forced,
          actions: [
            if (forced)
              TextButton(
                onPressed: _busy ? null : () => ref.read(authServiceProvider).signOut(),
                child: const Text('Sign out'),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (forced)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                        ),
                        child: const Text(
                          'You signed in with a temporary password. Choose your own password to continue.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    TextField(
                      controller: _current,
                      obscureText: !_showPasswords,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: forced ? 'Temporary password' : 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _new,
                      obscureText: !_showPasswords,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 8 characters, with a letter and a number.',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: !_showPasswords,
                      decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.check_outlined)),
                      onSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showPasswords = !_showPasswords),
                        icon: Icon(_showPasswords ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        label: Text(_showPasswords ? 'Hide passwords' : 'Show passwords'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Change password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
