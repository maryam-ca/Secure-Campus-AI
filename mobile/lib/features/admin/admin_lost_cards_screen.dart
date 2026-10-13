import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/admin_providers.dart';

class AdminLostCardsScreen extends ConsumerWidget {
  const AdminLostCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(lostCardReportsProvider);
    final dateFmt = DateFormat('dd MMM, hh:mm a');

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Could not load reports.\n$err')),
      data: (reports) => reports.isEmpty
          ? const Center(child: Text('No lost-card reports.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = reports[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.studentNameGuess.isEmpty ? 'Name not provided' : r.studentNameGuess,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (r.registrationNumberGuess.isNotEmpty) Text('Reg. no: ${r.registrationNumberGuess}'),
                        Text('Found at: ${r.location}'),
                        if (r.description.isNotEmpty) Text(r.description, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(r.createdAt != null ? dateFmt.format(r.createdAt!) : '—',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (r.notified)
                              const Text('Student notified', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))
                            else
                              ElevatedButton(
                                onPressed: r.registrationNumberGuess.isEmpty
                                    ? null
                                    : () async {
                                        final ok = await ref.read(adminRepositoryProvider).notifyStudentCardFound(r);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text(ok
                                                ? 'Student notified (Rs. 100 fine noted — informational only, no payment taken).'
                                                : 'No student found with that registration number.'),
                                          ));
                                        }
                                      },
                                child: const Text('Notify student'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
