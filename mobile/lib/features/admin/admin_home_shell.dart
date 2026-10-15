import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_shield_logo.dart';
import '../../providers/admin_navigation_provider.dart';
import '../../models/app_user.dart';
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
  static const _sections = [
    _AdminSection(
      'Dashboard',
      Icons.dashboard_outlined,
      AdminDashboardScreen(),
    ),
    _AdminSection('Students', Icons.school_outlined, AdminStudentsScreen()),
    _AdminSection('Courses', Icons.menu_book_outlined, AdminCoursesScreen()),
    _AdminSection(
      'Camera',
      Icons.videocam_outlined,
      AdminCameraControlScreen(),
    ),
    _AdminSection(
      'Library',
      Icons.local_library_outlined,
      AdminLibraryScreen(),
    ),
    _AdminSection(
      'Bus & Stops',
      Icons.directions_bus_filled_outlined,
      AdminBusScreen(),
    ),
    _AdminSection(
      'Gate & Security',
      Icons.shield_outlined,
      AdminGateSecurityScreen(),
    ),
    _AdminSection('Lost Cards', Icons.badge_outlined, AdminLostCardsScreen()),
    _AdminSection(
      'Staff Accounts',
      Icons.people_outline,
      AdminAccountsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final selected = ref.watch(adminSectionProvider);

    final drawerContent = NavigationDrawer(
      selectedIndex: selected,
      onDestinationSelected: (i) {
        ref.read(adminSectionProvider.notifier).state = i;
        if (!isWide) Navigator.of(context).pop();
      },
      children: [
        _DrawerHeader(user: ref.watch(currentAppUserProvider).valueOrNull),
        const SizedBox(height: 8),
        for (final s in _sections)
          NavigationDrawerDestination(icon: Icon(s.icon), label: Text(s.label)),
        const Divider(height: 24, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Change password'),
            onTap: () {
              if (!isWide) Navigator.of(context).pop();
              GoRouter.of(context).push('/change-password');
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
        ),
      ],
    );

    final body = Scaffold(
      appBar: AppBar(title: Text(_sections[selected].label)),
      drawer: isWide ? null : Drawer(child: drawerContent),
      body: _sections[selected].screen,
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

/// Branded block at the top of the Admin drawer: logo, app name, who is
/// signed in and their role.
class _DrawerHeader extends StatelessWidget {
  final AppUser? user;
  const _DrawerHeader({this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Administrator';
    final email = user?.email ?? '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 22, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyText, AppColors.primaryBlueDark, AppColors.primaryBlue],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The real app logo, same as the dashboard card and login.
              const AnimatedShieldLogo(size: 46, animate: false),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SecureCampus',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          if (email.isNotEmpty)
            Text(email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Administrator',
                style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
