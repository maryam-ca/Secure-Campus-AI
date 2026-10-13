import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../repositories/librarian_repository.dart';

final librarianRepositoryProvider = Provider<LibrarianRepository>((ref) => LibrarianRepository());

final librarianBooksProvider = StreamProvider.autoDispose<List<BookModel>>((ref) {
  return ref.watch(librarianRepositoryProvider).watchBooks();
});

final activeIssuesProvider = StreamProvider.autoDispose<List<LibrarianIssueRow>>((ref) {
  return ref.watch(librarianRepositoryProvider).watchActiveIssues();
});
