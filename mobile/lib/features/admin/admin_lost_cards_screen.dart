import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/lost_card_match.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';

/// Admin > Lost & Found > Lost Cards: reports from people who found a card.
/// Each report is checked against the real student record; only Admin can
/// notify the student and only Admin can resolve the report.
class AdminLostCardsScreen extends ConsumerWidget {
  const AdminLostCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(lostCardReportsProvider);

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Could not load reports.\n$err')),
      data: (all) {
        if (all.isEmpty) return const Center(child: Text('No lost-card reports.'));
        // open ones first, resolved ones after (each group keeps newest first)
        final reports = [...all.where((r) => !r.isResolved), ...all.where((r) => r.isResolved)];
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ReportCard(report: reports[i]),
        );
      },
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final LostCardReportModel report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = report;
    final dateFmt = DateFormat('dd MMM, hh:mm a');
    final registeredAsync = ref.watch(registeredNameProvider(r.registrationNumberGuess));
    final match = registeredAsync.whenData(
      (name) => (name: name, result: matchCard(registeredName: name, enteredName: r.studentNameGuess)),
    );

    return Opacity(
      opacity: r.isResolved ? 0.65 : 1,
      child: Card(
        key: ValueKey('report-${r.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.studentNameGuess.isEmpty ? 'Name not provided' : r.studentNameGuess,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (r.isResolved)
                    const Text('Resolved', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                ],
              ),
              if (r.registrationNumberGuess.isNotEmpty) Text('Reg. no: ${r.registrationNumberGuess}'),
              Text('Found at: ${r.location}'),
              if (r.description.isNotEmpty) Text(r.description, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(r.createdAt != null ? dateFmt.format(r.createdAt!) : '-',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
              const SizedBox(height: 8),
              match.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not check this report against the student records.',
                    style: TextStyle(color: AppColors.warning)),
                data: (m) => _MatchBadge(result: m.result, registeredName: m.name),
              ),
              // A report whose name and registration number match no student can
              // never be acted on, so Admin may delete it (Admin only).
              if (match.valueOrNull != null && match.valueOrNull!.result != CardMatch.verified) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: ValueKey('delete-${r.id}'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete report'),
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Delete this report?',
                        message: 'It does not match any student, so no one can be notified. '
                            'This removes it for Admin and Security and cannot be undone.',
                        confirmLabel: 'Delete',
                      );
                      if (confirmed) await ref.read(adminRepositoryProvider).deleteLostCardReport(r.id);
                    },
                  ),
                ),
              ],
              if (!r.isResolved) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (r.notified)
                      const Text('Student notified', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))
                    else
                      ElevatedButton(
                        key: ValueKey('notify-${r.id}'),
                        // only when name and registration number match one real student
                        onPressed: match.valueOrNull?.result != CardMatch.verified
                            ? null
                            : () async {
                                final ok = await ref.read(adminRepositoryProvider).notifyStudentCardFound(r);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(ok
                                        ? 'Student notified (Rs. 100 fine noted - informational only, no payment taken).'
                                        : 'Not sent: the name and registration number do not match a student.'),
                                  ));
                                }
                              },
                        child: const Text('Notify student'),
                      ),
                    OutlinedButton(
                      key: ValueKey('resolve-${r.id}'),
                      onPressed: () async {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: 'Resolve this report?',
                          message: 'Security will see it marked Resolved, and then it will disappear from their list.',
                          confirmLabel: 'Resolve',
                        );
                        if (confirmed) await ref.read(adminRepositoryProvider).resolveLostCardReport(r.id);
                      },
                      child: const Text('Mark resolved'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the name and registration number on a report belong to a real student.
class _MatchBadge extends StatelessWidget {
  final CardMatch result;
  final String? registeredName;
  const _MatchBadge({required this.result, required this.registeredName});

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (result) {
      CardMatch.verified => (Icons.verified_outlined, AppColors.success, 'Verified: matches $registeredName'),
      CardMatch.nameMismatch => (
          Icons.error_outline,
          AppColors.warning,
          'Name does not match the student with this registration number',
        ),
      CardMatch.unknownStudent => (Icons.help_outline, AppColors.error, 'No student has this registration number'),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    );
  }
}
