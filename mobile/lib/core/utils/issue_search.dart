import '../../models/admin_models.dart';
import 'student_search.dart';

/// Which way a book was confirmed on return. Stored with the return so
/// there is an audit trail of scanned versus typed returns.
enum ReturnMethod { scan, manual }

extension ReturnMethodX on ReturnMethod {
  String get id => name; // 'scan' | 'manual'
}

/// True when a scanned QR value or typed text is this book's ID
/// (case, dashes and spaces ignored: "book-001" == "BOOK-001").
bool bookCodeMatches(String scannedOrTyped, String bookId) {
  final a = normalizeRegNo(scannedOrTyped);
  return a.isNotEmpty && a == normalizeRegNo(bookId);
}

/// Filters the issued-books list. Matches when the text appears in the book
/// title, the book ID, the student's name or the student's registration
/// number (any part, case-insensitive; IDs also ignore dashes and spaces).
///
/// Fewer than [studentSearchMinChars] characters means "no filter": the full
/// list is returned so the librarian never faces an empty screen by typing a
/// single letter.
List<LibrarianIssueRow> searchIssues(List<LibrarianIssueRow> all, String query) {
  final text = query.trim().toLowerCase();
  if (text.length < studentSearchMinChars) return all;
  final id = normalizeRegNo(query);

  bool idHit(String value) => id.length >= studentSearchMinChars && normalizeRegNo(value).contains(id);

  return all
      .where((i) =>
          i.bookTitle.toLowerCase().contains(text) ||
          i.studentName.toLowerCase().contains(text) ||
          idHit(i.bookId) ||
          idHit(i.registrationNumber))
      .toList();
}
