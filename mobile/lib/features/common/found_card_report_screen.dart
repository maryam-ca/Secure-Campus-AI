import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/lost_card_match.dart';
import '../../providers/auth_provider.dart';

/// Reached by anyone who taps "Found a student card? Report it" on the
/// login screen - they're signed in anonymously first (see LoginScreen
/// / AuthService.signInAnonymously), which is enough to satisfy
/// firestore.rules' `allow create: if isSignedIn()` on lostCardReports
/// without requiring them to be a registered SecureCampus user.
///
/// Shares the login screen's campus-photo backdrop (real bug/consistency
/// fix here: previously this screen and the login screen looked like two
/// different apps) so the "signed in anonymously to report a card"
/// detour still feels like part of the same product, not a bare form.
class FoundCardReportScreen extends ConsumerStatefulWidget {
  const FoundCardReportScreen({super.key});

  @override
  ConsumerState<FoundCardReportScreen> createState() => _FoundCardReportScreenState();
}

class _FoundCardReportScreenState extends ConsumerState<FoundCardReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentName = TextEditingController();
  final _regNo = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  DateTime _foundAt = DateTime.now();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _foundAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _foundAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance.collection('lostCardReports').add({
        'studentName': _studentName.text.trim(),
        'registrationNumber': normalizeRegistration(_regNo.text),
        'status': 'OPEN',
        'location': _location.text.trim(),
        'description': _description.text.trim(),
        'foundAt': Timestamp.fromDate(_foundAt),
        'notified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _submitted = true);
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      setState(() => _error = 'Could not submit the report: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Shared photo backdrop for both this screen's states - real campus
  /// photo with a dark-to-light gradient scrim so text/cards stay
  /// legible regardless of what's underneath.
  Widget _backdrop() {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        body: Stack(
          children: [
            _backdrop(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Thank you',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your report has been sent to Admin and Security. Once the name and '
                        'registration number are checked, the student will be told to collect their card.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Report a Found Card'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to login',
          onPressed: _submitting ? null : () => ref.read(authServiceProvider).signOut(),
        ),
      ),
      body: Stack(
        children: [
          _backdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.badge_outlined, size: 36, color: AppColors.primaryBlueDark),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Found a campus ID?',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the name and registration number exactly as printed on the card. '
                        'Admin checks them against the student records before the owner is notified.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navyText.withValues(alpha: 0.15),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _studentName,
                                decoration: const InputDecoration(
                                  labelText: 'Student name (as on the card)',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) {
                                  final name = (v ?? '').trim();
                                  if (name.isEmpty) return 'Required - the name printed on the card';
                                  if (name.length < 3) return 'Enter the full name on the card';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _regNo,
                                decoration: const InputDecoration(
                                  labelText: 'Registration number (as on the card)',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                textCapitalization: TextCapitalization.characters,
                                validator: (v) {
                                  final reg = normalizeRegistration(v ?? '');
                                  if (reg.isEmpty) return 'Required - the number printed on the card';
                                  if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{2,29}$').hasMatch(reg)) {
                                    return 'Enter the registration number exactly as printed';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _location,
                                decoration: const InputDecoration(
                                  labelText: 'Where was it found?',
                                  prefixIcon: Icon(Icons.place_outlined),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.event_outlined, size: 18),
                                label: Text('Found on: ${_foundAt.toLocal().toString().split(' ').first}'),
                                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _description,
                                decoration: const InputDecoration(
                                  labelText: 'Additional description (optional)',
                                  prefixIcon: Icon(Icons.notes_outlined),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 3,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          elevation: 6,
                          shadowColor: AppColors.primaryBlue.withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                              )
                            : const Text('Submit Report'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _studentName.dispose();
    _regNo.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }
}