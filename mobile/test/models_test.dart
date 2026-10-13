import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/core/constants/roles.dart';
import 'package:securecampus/models/dashboard_models.dart';

void main() {
  group('UserRole', () {
    test('has exactly the five approved roles (no Teacher)', () {
      expect(UserRole.values.map((r) => r.id).toSet(),
          {'admin', 'student', 'security', 'librarian', 'driver'});
    });

    test('fromId maps stored strings and rejects unknown ones', () {
      expect(UserRoleX.fromId('librarian'), UserRole.librarian);
      expect(UserRoleX.fromId('teacher'), isNull);
      expect(UserRoleX.fromId(null), isNull);
    });
  });

  group('LibraryIssueModel.status', () {
    LibraryIssueModel issue({required Duration dueIn, bool returned = false}) => LibraryIssueModel(
          bookId: 'BOOK-001',
          bookTitle: 'Intro to Algorithms',
          issueDate: DateTime.now().subtract(const Duration(days: 7)),
          expiryDate: DateTime.now().add(dueIn),
          returned: returned,
        );

    test('issued while before the due date', () {
      expect(issue(dueIn: const Duration(days: 3)).status, LibraryIssueStatus.issued);
    });

    test('overdue after the due date', () {
      expect(issue(dueIn: const Duration(days: -1)).status, LibraryIssueStatus.overdue);
    });

    test('returned wins even if past the due date', () {
      expect(issue(dueIn: const Duration(days: -5), returned: true).status, LibraryIssueStatus.returned);
    });
  });

  group('BusAssignmentModel', () {
    test('parses a Firestore map and tolerates missing fields', () {
      final full = BusAssignmentModel.fromFirestore({'busId': 'BUS-001', 'stopId': 's1', 'stopName': 'Block A'});
      expect([full.busId, full.stopId, full.stopName], ['BUS-001', 's1', 'Block A']);

      final empty = BusAssignmentModel.fromFirestore({});
      expect([empty.busId, empty.stopId, empty.stopName], ['', '', '']);
    });
  });
}
