import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/portal_nav.dart';
import '../../core/widgets/portal_shell.dart';
import '../../providers/issue_report_providers.dart';
import 'librarian_catalog_screen.dart';
import 'librarian_reports_screen.dart';
import 'librarian_scan_screen.dart';

/// Which page of the Librarian portal is open.
final librarianPageProvider = StateProvider<String>((ref) => LibrarianPage.home);

class LibrarianPage {
  LibrarianPage._();
  static const home = 'home';
  static const catalog = 'catalog';
  static const reports = 'reports';
}

/// Three pages in the shared sidebar layout: Home (scan a book to issue or
/// return it), Catalog (All, Available, Issued, Overdue, Locked), and Reports
/// (summary + student reports).
class LibrarianHomeScreen extends ConsumerWidget {
  const LibrarianHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newReports = ref.watch(issueReportsProvider).valueOrNull?.where((r) => r.isOpen).length ?? 0;

    return PortalShell(
      roleLabel: 'Librarian',
      selection: librarianPageProvider,
      nav: PortalNav(
        home: const PortalItem(
          id: LibrarianPage.home,
          label: 'Home',
          description: 'Scan a book to issue or return it',
          icon: Icons.home_outlined,
          screen: LibrarianScanScreen(),
        ),
        topItems: [
          const PortalItem(
            id: LibrarianPage.catalog,
            label: 'Catalog',
            description: 'All books, availability and locks',
            icon: Icons.menu_book_outlined,
            screen: LibrarianCatalogScreen(),
          ),
          PortalItem(
            id: LibrarianPage.reports,
            label: 'Reports',
            description: 'Library summary and student reports on issued books',
            icon: Icons.assessment_outlined,
            badge: newReports,
            screen: const LibrarianReportsScreen(),
          ),
        ],
      ),
    );
  }
}
