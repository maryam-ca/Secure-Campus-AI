import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> issueBook({
    required BookModel book,
    required StudentModel student,
    required DateTime issueDate,
    required DateTime expiryDate,
  }) async {
    final batch = _db.batch();
    final issueRef = _db.collection('libraryIssues').doc();
    batch.set(issueRef, {
      'bookId': book.id,
      'bookTitle': book.title,
      'studentId': student.uid,
      'studentName': student.name,
      'registrationNumber': student.registrationNumber,
      'issueDate': Timestamp.fromDate(issueDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'returned': false,
    });
    batch.update(_db.collection('books').doc(book.id), {'available': false});
    await batch.commit();
  }

  Future<void> returnBook(LibrarianIssueRow issue) async {
    final batch = _db.batch();
    batch.update(_db.collection('libraryIssues').doc(issue.id), {'returned': true});
    batch.update(_db.collection('books').doc(issue.bookId), {'available': true});
    await batch.commit();
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
