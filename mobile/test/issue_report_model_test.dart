import 'package:flutter_test/flutter_test.dart';
import 'package:securecampus/models/issue_report_model.dart';

void main() {
  test('parses a report and treats NEW as open', () {
    final r = IssueReportModel.fromMap('r1', {
      'issueId': 'i1',
      'bookId': 'BOOK-001',
      'bookTitle': 'Intro to Algorithms',
      'studentId': 's1',
      'studentName': 'Ayesha',
      'registrationNumber': 'FA23-BSE-032',
      'note': 'Never took it',
      'status': 'NEW',
    });
    expect(r.id, 'r1');
    expect(r.bookTitle, 'Intro to Algorithms');
    expect(r.registrationNumber, 'FA23-BSE-032');
    expect(r.isOpen, isTrue);
    expect(r.createdAt, isNull); // server timestamp not yet resolved
  });

  test('RESOLVED is closed; missing fields fall back safely', () {
    final resolved = IssueReportModel.fromMap('r2', {'status': 'RESOLVED'});
    expect(resolved.isOpen, isFalse);

    final empty = IssueReportModel.fromMap('r3', {});
    expect(empty.status, IssueReportModel.statusNew);
    expect(empty.bookTitle, 'Unknown title');
    expect(empty.note, '');
  });
}
