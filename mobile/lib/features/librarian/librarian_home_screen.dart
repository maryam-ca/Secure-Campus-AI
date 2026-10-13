import 'package:flutter/material.dart';

import '../../core/constants/roles.dart';
import '../../core/widgets/portal_scaffold.dart';
import 'librarian_catalog_screen.dart';
import 'librarian_issued_books_screen.dart';
import 'librarian_scan_screen.dart';

class LibrarianHomeScreen extends StatefulWidget {
  const LibrarianHomeScreen({super.key});

  @override
  State<LibrarianHomeScreen> createState() => _LibrarianHomeScreenState();
}

class _LibrarianHomeScreenState extends State<LibrarianHomeScreen> {
  int _tab = 0;

  static const _screens = [
    LibrarianScanScreen(),
    LibrarianIssuedBooksScreen(),
    LibrarianCatalogScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(
      title: 'Library Desk',
      role: UserRole.librarian,
      body: _screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), label: 'Scan & Issue'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Issued'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Catalog'),
        ],
      ),
    );
  }
}
