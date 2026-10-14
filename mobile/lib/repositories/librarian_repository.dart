import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/utils/issue_search.dart';
import '../models/admin_models.dart';
import '../models/student_model.dart';

class LibrarianRepository {
  final FirebaseFirestore _db;
  LibrarianRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  Stream<List<BookModel>> watchBooks() {
    return _db.collection('books').orderBy(FieldPath.documentId).snapshots().map(
        (s) => s.docs.map(BookModel.fromFirestore).toList());
  }

  Future<BookModel?> fetchBookById(String id) async {
    final doc = await _db.collection('books').doc(id).get();
    if (!doc.exists) return null;
    return BookModel.fromFirestore(doc);
  }

  /// Spec §26: librarian manually types the registration number (not a
  /// student browser/picker). We still look the student up by that
  /// number so the resulting loan is linked to their real account and
  /// shows up in their own portal (spec §27) - this is what "manual
  /// entry" needs to mean for the app to actually work end to end,
  /// while keeping the same manual-typing workflow the spec describes.
  Future<StudentModel?> findStudentByRegistrationNumber(String regNo) async {
    final snap = await _db.collection('students').where('registrationNumber', isEqualTo: regNo).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return StudentModel.fromFirestore(snap.docs.first);
  }

  /// Every student record, loaded once when the issue sheet opens so the
  /// librarian can find a student by typing only the last digits of the
  /// registration number (Firestore cannot query "ends with"). The librarian
  /// role may read `students` (firestore.rules); fine for a campus-sized list.
  Future<List<StudentModel>> fetchAllStudents() async {
    final snap = await _db.collection('students').get();
    return snap.docs.map(StudentModel.fromFirestore).toList();
  }

  /// Issues a book. The book is re-read inside a transaction, so a book that
  /// was locked or issued by someone else a moment ago is refused instead of
  /// being issued twice.
  Future<void> issueBook({
    required BookModel book,
    required StudentModel student,
    required DateTime issueDate,
    required DateTime expiryDate,
  }) async {
    final bookRef = _db.collection('books').doc(book.id);
    final issueRef = _db.collection('libraryIssues').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(bookRef);
      final data = snap.data() ?? {};
      if (data['locked'] == true) {
        final why = (data['lockReason'] as String? ?? '').trim();
        throw StateError('This book is locked${why.isEmpty ? '' : ': $why'}. It cannot be issued.');
      }
      if ((data['available'] as bool? ?? true) == false) {
        throw StateError('This book is already issued to someone else.');
      }

      tx.set(issueRef, {
        'bookId': book.id,
        'bookTitle': book.title,
        'studentId': student.uid,
        'studentName': student.name,
        'registrationNumber': student.registrationNumber,
        'issueDate': Timestamp.fromDate(issueDate),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'returned': false,
      });
      tx.update(bookRef, {'available': false});
    });
  }

  /// Marks the loan returned and frees the book. [method] records how the
  /// librarian confirmed it (scanned the book's QR, or typed its ID), plus
  /// who and when, so returns can be audited later.
  Future<void> returnBook(LibrarianIssueRow issue, {required ReturnMethod method}) async {
    final batch = _db.batch();
    batch.update(_db.collection('libraryIssues').doc(issue.id), {
      'returned': true,
      'returnedAt': FieldValue.serverTimestamp(),
      'returnedBy': FirebaseAuth.instance.currentUser?.uid,
      'returnMethod': method.id,
    });
    batch.update(_db.collection('books').doc(issue.bookId), {'available': true});
    await batch.commit();
  }

  /// The open loan for a book, if any (used when a librarian scans a book
  /// that is already issued, so it can be returned right from the scan).
  Future<LibrarianIssueRow?> fetchActiveIssueForBook(String bookId) async {
    final snap = await _db
        .collection('libraryIssues')
        .where('bookId', isEqualTo: bookId)
        .where('returned', isEqualTo: false)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return LibrarianIssueRow.fromFirestore(snap.docs.first);
  }

  Stream<List<LibrarianIssueRow>> watchActiveIssues() {
    return _db
        .collection('libraryIssues')
        .where('returned', isEqualTo: false)
        .orderBy('expiryDate')
        .snapshots()
        .map((s) => s.docs.map(LibrarianIssueRow.fromFirestore).toList());
  }
}
