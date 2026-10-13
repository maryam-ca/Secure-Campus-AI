import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'admin_accounts_screen.dart';
import 'admin_bus_screen.dart';
import 'admin_camera_control_screen.dart';
import 'admin_courses_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_gate_security_screen.dart';
import 'admin_library_screen.dart';
import 'admin_lost_cards_screen.dart';
import 'admin_students_screen.dart';

class _AdminSection {
  final String label;
  final IconData icon;
  final Widget screen;
  const _AdminSection(this.label, this.icon, this.screen);
}

class AdminHomeShell extends ConsumerStatefulWidget {
  const AdminHomeShell({super.key});

  @override
  ConsumerState<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends ConsumerState<AdminHomeShell> {
  int _selected = 0;

  static const _sections = [
    _AdminSection('Dashboard', Icons.dashboard_outlined, AdminDashboardScreen()),
    _AdminSection('Students', Icons.school_outlined, AdminStudentsScreen()),
    _AdminSection('Courses', Icons.menu_book_outlined, AdminCoursesScreen()),
    _AdminSection('Camera', Icons.videocam_outlined, AdminCameraControlScreen()),
    _AdminSection('Library', Icons.local_library_outlined, AdminLibraryScreen()),
    _AdminSection('Bus & Stops', Icons.directions_bus_filled_outlined, AdminBusScreen()),
    _AdminSection('Gate & Security', Icons.shield_outlined, AdminGateSecurityScreen()),
    _AdminSection('Lost Cards', Icons.badge_outlined, AdminLostCardsScreen()),
    _AdminSection('Staff Accounts', Icons.people_outline, AdminAccountsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final drawerContent = NavigationDrawer(
      selectedIndex: _selected,
      onDestinationSelected: (i) {
        setState(() => _selected = i);
        if (!isWide) Navigator.of(context).pop();
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 16, 12),
          child: Text('SecureCampus Admin',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.navyText)),
        ),
        for (final s in _sections) NavigationDrawerDestination(icon: Icon(s.icon), label: Text(s.label)),
        const Divider(height: 24, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Sign out', style: TextStyle(color: AppColors.error)),
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
        ),
      ],
    );

    final body = Scaffold(
      appBar: AppBar(title: Text(_sections[_selected].label)),
      drawer: isWide ? null : Drawer(child: drawerContent),
      body: _sections[_selected].screen,
    );

    if (!isWide) return body;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 260, child: drawerContent),
          const VerticalDivider(width: 1, color: AppColors.divider),
          Expanded(child: body),
        ],
      ),
    );
  }
}
