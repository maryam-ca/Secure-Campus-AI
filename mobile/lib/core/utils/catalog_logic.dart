import '../../models/admin_models.dart';
import 'issue_search.dart';
import 'student_search.dart';

/// Catalog sub-tabs for the librarian.
enum CatalogFilter { all, available, issued, overdue, locked }

/// What state a single book is in. A locked book is one that has been
/// received and is kept in the safe; an issued book is out with a student.
enum BookState { available, issued, locked }

BookState bookState(BookModel b) {
  if (b.locked) return BookState.locked;
  if (!b.available) return BookState.issued;
  return BookState.available;
}

/// Numbers shown under each Catalog sub-tab.
///
/// [overdue] counts loans that are past their due date; those books are also
/// counted in [issued], so the sub-tab numbers do not add up to [all].
class CatalogCounts {
  final int all;
  final int available;
  final int issued;
  final int overdue;
  final int locked;

  const CatalogCounts({
    required this.all,
    required this.available,
    required this.issued,
    required this.overdue,
    required this.locked,
  });

  int forFilter(CatalogFilter f) {
    switch (f) {
      case CatalogFilter.all:
        return all;
      case CatalogFilter.available:
        return available;
      case CatalogFilter.issued:
        return issued;
      case CatalogFilter.overdue:
        return overdue;
      case CatalogFilter.locked:
        return locked;
    }
  }
}

CatalogCounts catalogCounts(List<BookModel> books, List<LibrarianIssueRow> activeLoans) {
  var available = 0, issued = 0, locked = 0;
  for (final b in books) {
    switch (bookState(b)) {
      case BookState.available:
        available++;
      case BookState.issued:
        issued++;
      case BookState.locked:
        locked++;
    }
  }
  return CatalogCounts(
    all: books.length,
    available: available,
    issued: issued,
    overdue: activeLoans.where((l) => l.isOverdue).length,
    locked: locked,
  );
}

/// Books shown for the book-based sub-tabs (All, Available, Locked) and
/// optionally narrowed by a text search over title, ID and author.
/// Issued and Overdue are loan lists, not book lists: see [loansForFilter].
List<BookModel> booksForFilter(List<BookModel> books, CatalogFilter f, String query) {
  Iterable<BookModel> result = books;
  switch (f) {
    case CatalogFilter.available:
      result = result.where((b) => bookState(b) == BookState.available);
    case CatalogFilter.locked:
      result = result.where((b) => bookState(b) == BookState.locked);
    case CatalogFilter.all:
    case CatalogFilter.issued:
    case CatalogFilter.overdue:
      break;
  }
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((b) =>
        b.title.toLowerCase().contains(q) || b.id.toLowerCase().contains(q) || b.author.toLowerCase().contains(q));
  }
  return result.toList();
}

/// Loans shown for the Issued and Overdue sub-tabs, searchable by book title,
/// book ID, student name or student ID (see [searchIssues]).
List<LibrarianIssueRow> loansForFilter(List<LibrarianIssueRow> loans, CatalogFilter f, String query) {
  final searched = searchIssues(loans, query);
  return f == CatalogFilter.overdue ? searched.where((l) => l.isOverdue).toList() : searched;
}

/// Books whose ID CONTAINS what was typed (any part, case/dashes/spaces
/// ignored: "001", "book 1", "bk-0") or whose title or author contains it.
/// Works for any ID format, old or new. Sorted by ID. Fewer than
/// [studentSearchMinChars] characters returns nothing.
List<BookModel> searchBooks(List<BookModel> all, String query) {
  final text = query.trim().toLowerCase();
  final id = normalizeRegNo(query);
  if (id.length < studentSearchMinChars && text.length < studentSearchMinChars) return const [];

  return all.where((b) {
    final idHit = id.length >= studentSearchMinChars && normalizeRegNo(b.id).contains(id);
    final textHit = text.length >= studentSearchMinChars &&
        (b.title.toLowerCase().contains(text) || b.author.toLowerCase().contains(text));
    return idHit || textHit;
  }).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
}

/// The one book a scanned or fully typed code means, ignoring case, dashes
/// and spaces ("book-001" finds "BOOK-001"). Null if none, or if it is
/// ambiguous (two IDs that differ only by punctuation).
BookModel? bookForCode(List<BookModel> all, String code) {
  final n = normalizeRegNo(code);
  if (n.isEmpty) return null;
  final hits = all.where((b) => normalizeRegNo(b.id) == n).toList();
  return hits.length == 1 ? hits.first : null;
}
