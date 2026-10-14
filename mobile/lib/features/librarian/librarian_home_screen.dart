import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/roles.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../providers/issue_report_providers.dart';
import 'librarian_catalog_screen.dart';
import 'librarian_reports_screen.dart';
import 'librarian_scan_screen.dart';

/// Three tabs: Home (scan a book to issue or return it), Catalog (All,
/// Available, Issued, Overdue, Locked), and Reports (summary + student reports).
class LibrarianHomeScreen extends ConsumerStatefulWidget {
  const LibrarianHomeScreen({super.key});

  @override
  ConsumerState<LibrarianHomeScreen> createState() => _LibrarianHomeScreenState();
}

class _LibrarianHomeScreenState extends ConsumerState<LibrarianHomeScreen> {
  int _tab = 0;

  static const _screens = [
    LibrarianScanScreen(),
    LibrarianCatalogScreen(),
    LibrarianReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final newReports = ref.watch(issueReportsProvider).value?.where((r) => r.isOpen).length ?? 0;

    return PortalScaffold(
      title: 'Library Desk',
      role: UserRole.librarian,
      body: _screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Catalog'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: newReports > 0,
              label: Text('$newReports'),
              child: const Icon(Icons.assessment_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: newReports > 0,
              label: Text('$newReports'),
              child: const Icon(Icons.assessment),
            ),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
