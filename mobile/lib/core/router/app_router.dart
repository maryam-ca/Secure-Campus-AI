import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_home_shell.dart';
import '../../features/auth/change_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/common/account_error_screen.dart';
import '../../features/common/found_card_report_screen.dart';
import '../../features/common/splash_screen.dart';
import '../../features/driver/driver_dashboard_screen.dart';
import '../../features/librarian/librarian_home_screen.dart';
import '../../features/security/security_dashboard_screen.dart';
import '../../features/student/student_dashboard_screen.dart';
import '../../providers/auth_provider.dart';
import '../constants/roles.dart';
import 'password_gate.dart';
import 'role_paths.dart';

/// Bridges a Stream into a Listenable so go_router's `refreshListenable`
/// re-evaluates `redirect` whenever auth state or the user's role
/// document changes - not just on explicit navigation calls.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

String _pathForRole(UserRole role) => homePathForRole(role);

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = GoRouterRefreshStream(ref.watch(firebaseAuthStateProvider.stream));
  final userRefresh = GoRouterRefreshStream(ref.watch(currentAppUserProvider.stream));
  ref.onDispose(() {
    authRefresh.dispose();
    userRefresh.dispose();
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([authRefresh, userRefresh]),
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/account-error', builder: (_, __) => const AccountErrorScreen()),
      GoRoute(path: '/change-password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/report-lost-card', builder: (_, __) => const FoundCardReportScreen()),
      GoRoute(path: '/student', builder: (_, __) => const StudentDashboardScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminHomeShell()),
      GoRoute(path: '/security', builder: (_, __) => const SecurityDashboardScreen()),
      GoRoute(path: '/librarian', builder: (_, __) => const LibrarianHomeScreen()),
      GoRoute(path: '/driver', builder: (_, __) => const DriverDashboardScreen()),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final authAsync = ref.read(firebaseAuthStateProvider);
  final loc = state.matchedLocation;

  if (authAsync.isLoading) {
    return loc == '/splash' ? null : '/splash';
  }

  final firebaseUser = authAsync.valueOrNull;
  if (firebaseUser == null) {
    return loc == '/login' ? null : '/login';
  }

  // Anonymous sessions only ever exist for the public "report a found
  // card" flow (see LoginScreen._reportFoundCard) - they never have a
  // users/{uid} doc and must never fall through to /account-error.
  if (firebaseUser.isAnonymous) {
    return loc == '/report-lost-card' ? null : '/report-lost-card';
  }

  final appUserAsync = ref.read(currentAppUserProvider);
  if (appUserAsync.isLoading) {
    return loc == '/splash' ? null : '/splash';
  }

  final appUser = appUserAsync.valueOrNull;
  if (appUser == null || !appUser.active) {
    return loc == '/account-error' ? null : '/account-error';
  }

  // First login with a temporary password: must choose a new one before anything else.
  final gate = passwordGateRedirect(
    user: appUser,
    location: loc,
    enforced: passwordChangeEnforced,
    changedThisSession: ref.read(passwordChangedThisSessionProvider),
  );
  if (gate != null) return gate;
  // Anyone signed in may open the change-password screen voluntarily.
  if (loc == '/change-password') return null;

  final targetPath = _pathForRole(appUser.role);
  final onCorrectPortal = loc.startsWith(targetPath);
  if (!onCorrectPortal) {
    return targetPath;
  }

  return null;
}
