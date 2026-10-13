import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/issue_report_model.dart';
import '../repositories/issue_report_repository.dart';

final issueReportRepositoryProvider = Provider<IssueReportRepository>((ref) => IssueReportRepository());

/// Staff-only stream (Librarian / Security / Admin) - firestore.rules reject
/// it for every other role.
final issueReportsProvider = StreamProvider.autoDispose<List<IssueReportModel>>((ref) {
  return ref.watch(issueReportRepositoryProvider).watchAll();
});
