import 'package:flutter/material.dart';

import '../../core/widgets/portal_shell.dart';
import '../../providers/admin_navigation_provider.dart';
import 'admin_nav.dart';

/// The Admin portal: the shared shell with the Admin menu.
class AdminHomeShell extends StatelessWidget {
  const AdminHomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      nav: AdminNav.nav,
      selection: adminSectionProvider,
      roleLabel: 'Administrator',
    );
  }
}
