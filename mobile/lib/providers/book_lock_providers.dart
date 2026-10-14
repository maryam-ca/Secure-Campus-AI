import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/roles.dart';
import '../models/admin_models.dart';
import '../repositories/book_lock_repository.dart';
import 'auth_provider.dart';

final bookLockRepositoryProvider = Provider<BookLockRepository>((ref) => BookLockRepository());

/// A book's lock/unlock history, newest first.
final bookLockHistoryProvider = StreamProvider.autoDispose.family<List<BookLockEvent>, String>((ref, bookId) {
  return ref.watch(bookLockRepositoryProvider).watchHistory(bookId);
});

/// The signed-in Librarian/Admin as the actor recorded in lock history, or
/// null when nobody is signed in.
final lockActorProvider = Provider<LockActor?>((ref) {
  final user = ref.watch(currentAppUserProvider).value;
  if (user == null) return null;
  return LockActor(uid: user.uid, name: user.name.isEmpty ? user.email : user.name, role: user.role.id);
});
