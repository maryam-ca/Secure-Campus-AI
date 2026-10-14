import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';

/// Who is locking or unlocking a book (stored in the book's history).
class LockActor {
  final String uid;
  final String name;
  final String role; // 'librarian' | 'admin'
  const LockActor({required this.uid, required this.name, required this.role});
}

/// A lock/unlock request that cannot go ahead, with a message fit to show
/// the librarian as-is.
class BookLockException implements Exception {
  final String message;
  const BookLockException(this.message);
  @override
  String toString() => message;
}

/// Locking keeps a book out of circulation (physically in the safe).
///
/// Rules enforced here, inside one Firestore transaction so two people cannot
/// race each other:
///  * a book can only be locked when it has been received (it is not issued);
///  * a reason is required for both locking and unlocking;
///  * every lock and unlock appends a history entry with who, role, when, why.
class BookLockRepository {
  final FirebaseFirestore _db;
  BookLockRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> lockBook({required String bookId, required String reason, required LockActor actor}) async {
    final why = reason.trim();
    if (why.isEmpty) throw const BookLockException('Please enter the reason for locking this book.');

    final bookRef = _db.collection('books').doc(bookId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(bookRef);
      if (!snap.exists) throw const BookLockException('Book not found.');
      final data = snap.data() ?? {};

      if (data['locked'] == true) throw const BookLockException('This book is already locked.');
      if ((data['available'] as bool? ?? true) == false) {
        throw const BookLockException(
            'This book is currently issued. Receive (return) it first, then lock it.');
      }

      tx.update(bookRef, {
        'locked': true,
        'lockReason': why,
        'lockedByUid': actor.uid,
        'lockedByName': actor.name,
        'lockedAt': FieldValue.serverTimestamp(),
      });
      tx.set(bookRef.collection('lockHistory').doc(), _event(BookLockEvent.lockAction, why, actor));
    });
  }

  Future<void> unlockBook({required String bookId, required String reason, required LockActor actor}) async {
    final why = reason.trim();
    if (why.isEmpty) throw const BookLockException('Please enter the reason for unlocking this book.');

    final bookRef = _db.collection('books').doc(bookId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(bookRef);
      if (!snap.exists) throw const BookLockException('Book not found.');
      if ((snap.data() ?? {})['locked'] != true) throw const BookLockException('This book is not locked.');

      tx.update(bookRef, {
        'locked': false,
        'lockReason': '',
        'lockedByUid': FieldValue.delete(),
        'lockedByName': '',
        'lockedAt': FieldValue.delete(),
      });
      tx.set(bookRef.collection('lockHistory').doc(), _event(BookLockEvent.unlockAction, why, actor));
    });
  }

  /// Newest first.
  Stream<List<BookLockEvent>> watchHistory(String bookId) {
    return _db
        .collection('books')
        .doc(bookId)
        .collection('lockHistory')
        .orderBy('at', descending: true)
        .snapshots()
        .map((s) => s.docs.map(BookLockEvent.fromFirestore).toList());
  }

  Map<String, dynamic> _event(String action, String reason, LockActor actor) => {
        'action': action,
        'reason': reason,
        'byUid': actor.uid,
        'byName': actor.name,
        'byRole': actor.role,
        'at': FieldValue.serverTimestamp(),
      };
}
