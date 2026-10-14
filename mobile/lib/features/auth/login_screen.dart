import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/demo_accounts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_shield_logo.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'demo_accounts_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  /// One-tap test accounts. Empty (so no button) unless a debug build was
  /// given DEMO_ACCOUNTS; overridable so tests can supply their own.
  final List<DemoAccount>? demoAccounts;

  const LoginScreen({super.key, this.demoAccounts});

  List<DemoAccount> get accounts => demoAccounts ?? DemoAccounts.all;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _signIn(_emailController.text, _passwordController.text);
  }

  Future<void> _signIn(String email, String password) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signIn(email: email, password: password);
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showDemoAccounts() async {
    final chosen = await showModalBottomSheet<DemoAccount>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DemoAccountsSheet(accounts: widget.accounts),
    );
    if (chosen != null) {
      _emailController.text = chosen.email;
      await _signIn(chosen.email, chosen.password);
    }
  }

  Future<void> _reportFoundCard() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authServiceProvider).signInAnonymously();
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not start the report form. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Real campus photo as the backdrop, with a dark-to-light
          // gradient scrim over it so the white sign-in card (and its
          // dark text) stays readable regardless of what's underneath
          // - a plain photo with no overlay would make text contrast
          // unpredictable depending on the image's own brightness.
          Image.asset('assets/images/campus_building.jpg', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.navyText.withValues(alpha: 0.55),
                  AppColors.navyText.withValues(alpha: 0.35),
                  const Color(0xFFEAF2FF).withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.38, 0.75],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrandHeader(context),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: AppColors.navyText.withValues(alpha: 0.15), blurRadius: 28, offset: const Offset(0, 12)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Sign in', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 4),
                              Text(
                                'Use the account credentials provided by Admin.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Email is required';
                                  if (!value.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Password is required';
                                  return null;
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Sign in'),
                              ),
                              if (widget.accounts.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _isSubmitting ? null : _showDemoAccounts,
                                  icon: const Icon(Icons.science_outlined, size: 18),
                                  label: const Text('Demo accounts'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Forgot your password? Contact Admin for a reset.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.navyText, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _isSubmitting ? null : _reportFoundCard,
                          style: TextButton.styleFrom(foregroundColor: AppColors.navyText),
                          child: const Text(
                            'Found a student card? Report it',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Column(
      children: [
        const AnimatedShieldLogo(),
        const SizedBox(height: 18),
        Text(
          'SecureCampus',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, color: Colors.white),
        ),
        Text(
          'Smart Campus Security & Management',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
      ],
    );
  }
}