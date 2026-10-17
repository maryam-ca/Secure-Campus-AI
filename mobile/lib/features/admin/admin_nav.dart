import 'package:flutter/material.dart';

import '../../core/widgets/portal_nav.dart';
import '../../providers/admin_navigation_provider.dart';
import 'admin_accounts_screen.dart';
import 'admin_bus_screen.dart';
import 'admin_courses_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_library_screen.dart';
import 'admin_lost_cards_screen.dart';
import 'admin_stops_screen.dart';
import 'admin_students_screen.dart';

/// The Admin portal's menu, as data. The shared shell (core/widgets/portal_shell)
/// draws the sidebar, header bar and page from this one list, so adding,
/// renaming or moving a module is a change here and nowhere else.
///
/// To turn a Phase 2 module on later: give its item a `screen` and move it
/// into a Phase 1 group. Items without a screen show greyed out and cannot be
/// opened.
class AdminNav {
  AdminNav._();

  static const dashboard = PortalItem(
    id: AdminSection.dashboard,
    label: 'Dashboard',
    description: 'Overview of the campus today',
    icon: Icons.dashboard_outlined,
    screen: AdminDashboardScreen(),
  );

  static const groups = <PortalGroup>[
    PortalGroup(
      id: 'group.users',
      label: 'User Management',
      description: 'Student records and staff accounts',
      icon: Icons.groups_outlined,
      items: [
        PortalItem(
          id: AdminSection.students,
          label: 'Students',
          description: 'Add, import and review student records',
          icon: Icons.school_outlined,
          screen: AdminStudentsScreen(),
        ),
        PortalItem(
          id: AdminSection.staffSecurity,
          label: 'Security Staff',
          description: 'Accounts for gate security staff',
          icon: Icons.security_outlined,
          screen: AdminAccountsScreen(role: 'security'),
        ),
        PortalItem(
          id: AdminSection.staffLibrarian,
          label: 'Librarians',
          description: 'Accounts for library staff',
          icon: Icons.local_library_outlined,
          screen: AdminAccountsScreen(role: 'librarian'),
        ),
        PortalItem(
          id: AdminSection.staffDriver,
          label: 'Drivers',
          description: 'Accounts for bus drivers',
          icon: Icons.drive_eta_outlined,
          screen: AdminAccountsScreen(role: 'driver'),
        ),
      ],
    ),
    PortalGroup(
      id: 'group.academics',
      label: 'Academics',
      description: 'Courses and enrolment',
      icon: Icons.menu_book_outlined,
      items: [
        PortalItem(
          id: AdminSection.courses,
          label: 'Courses',
          description: 'Courses and the students enrolled in them',
          icon: Icons.menu_book_outlined,
          screen: AdminCoursesScreen(),
        ),
      ],
    ),
    PortalGroup(
      id: 'group.library',
      label: 'Library',
      description: 'Book catalog and library reports',
      icon: Icons.local_library_outlined,
      items: [
        PortalItem(
          id: AdminSection.libraryCatalog,
          label: 'Catalog',
          description: 'Books, availability and locks',
          icon: Icons.auto_stories_outlined,
          screen: AdminLibraryScreen(),
        ),
        PortalItem(
          id: AdminSection.libraryReports,
          label: 'Reports',
          description: 'Library summary and student reports on issued books',
          icon: Icons.assessment_outlined,
          screen: AdminLibraryScreen(initialTab: 1),
        ),
      ],
    ),
    PortalGroup(
      id: 'group.transport',
      label: 'Transport',
      description: 'Buses, stops and student assignment',
      icon: Icons.directions_bus_filled_outlined,
      items: [
        PortalItem(
          id: AdminSection.bus,
          label: 'Buses',
          description: 'Live map, seats, campus location and which students ride',
          icon: Icons.directions_bus_filled_outlined,
          screen: AdminBusScreen(),
        ),
        PortalItem(
          id: AdminSection.stops,
          label: 'Stops',
          description: 'The route, stop by stop, in the order the bus visits them',
          icon: Icons.pin_drop_outlined,
          screen: AdminStopsScreen(),
        ),
      ],
    ),
    PortalGroup(
      id: 'group.lost-found',
      label: 'Lost & Found',
      description: 'Lost and found ID cards',
      icon: Icons.badge_outlined,
      items: [
        PortalItem(
          id: AdminSection.lostCards,
          label: 'Lost Cards',
          description: 'ID cards reported lost or found',
          icon: Icons.badge_outlined,
          screen: AdminLostCardsScreen(),
        ),
      ],
    ),
  ];

  /// Phase 2: shown in the sidebar so the full plan is visible, but not
  /// clickable until the iris camera work is done.
  static const phase2 = PortalGroup(
    id: 'group.phase2',
    label: 'Phase 2',
    description: 'Planned features, not available yet',
    icon: Icons.construction_outlined,
    phase: 2,
    items: [
      PortalItem(
        id: AdminSection.camera,
        label: 'Iris Recognition',
        description: 'Camera control and iris enrollment',
        icon: Icons.videocam_outlined,
        phase: 2,
      ),
      PortalItem(
        id: AdminSection.attendance,
        label: 'Class Attendance',
        description: 'Attendance from iris matches in class',
        icon: Icons.fact_check_outlined,
        phase: 2,
      ),
      PortalItem(
        id: AdminSection.gateSecurity,
        label: 'Gate & Security',
        description: 'Gate entries and unknown-person alerts',
        icon: Icons.shield_outlined,
        phase: 2,
      ),
      PortalItem(
        id: AdminSection.settings,
        label: 'Settings',
        description: 'My account, library rules, notifications and iris settings',
        icon: Icons.settings_outlined,
        phase: 2,
      ),
    ],
  );

  static const nav = PortalNav(home: dashboard, groups: groups, planned: phase2);
}
