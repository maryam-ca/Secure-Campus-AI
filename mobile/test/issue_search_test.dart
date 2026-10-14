import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/utils/issue_search.dart';
import 'package:securecampus/models/admin_models.dart';

LibrarianIssueRow _i(String id, String bookId, String title, String student, String reg, {int dueInDays = 5}) =>
    LibrarianIssueRow(
      id: id,
      bookId: bookId,
      bookTitle: title,
      studentId: 'uid-$reg',
      studentName: student,
      registrationNumber: reg,
      issueDate: DateTime.now().subtract(const Duration(days: 3)),
      expiryDate: DateTime.now().add(Duration(days: dueInDays)),
      returned: false,
    );

final _issues = [
  _i('1', 'BOOK-001', 'Introduction to Algorithms', 'Ayesha Khan', 'FA23-BSE-001'),
  _i('2', 'BOOK-002', 'Computer Networking', 'Bilal Ahmed', 'FA23-BSE-002'),
  _i('3', 'BOOK-003', 'Database System Concepts', 'Ayesha Malik', 'FA22-BSE-007', dueInDays: -2),
];

List<String> _ids(String q) => searchIssues(_issues, q).map((i) => i.id).toList();

void main() {
  group('searchIssues', () {
    test('by book title, in any case', () {
      expect(_ids('algorithms'), ['1']);
      expect(_ids('DATABASE'), ['3']);
    });

    test('by book ID in any format', () {
      expect(_ids('BOOK-002'), ['2']);
      expect(_ids('book002'), ['2']);
      expect(_ids('book'), ['1', '2', '3']); // every ID contains it
    });

    test('by student name or registration number (any part)', () {
      expect(_ids('ayesh'), ['1', '3']);
      expect(_ids('007'), ['3']);
      expect(_ids('fa23 bse'), ['1', '2']);
    });

    test('fewer than 2 characters, or empty, shows everything', () {
      expect(_ids(''), ['1', '2', '3']);
      expect(_ids('a'), ['1', '2', '3']);
    });

    test('no match gives an empty list', () {
      expect(_ids('zzzz'), isEmpty);
    });
  });

  group('bookCodeMatches', () {
    test('accepts the same ID in any case, with dashes or spaces', () {
      expect(bookCodeMatches('BOOK-001', 'BOOK-001'), isTrue);
      expect(bookCodeMatches('book-001', 'BOOK-001'), isTrue);
      expect(bookCodeMatches(' book 001 ', 'BOOK-001'), isTrue);
    });

    test('rejects a different book, a partial ID and empty input', () {
      expect(bookCodeMatches('BOOK-002', 'BOOK-001'), isFalse);
      expect(bookCodeMatches('BOOK-00', 'BOOK-001'), isFalse);
      expect(bookCodeMatches('', 'BOOK-001'), isFalse);
      expect(bookCodeMatches('---', 'BOOK-001'), isFalse);
    });
  });
}
