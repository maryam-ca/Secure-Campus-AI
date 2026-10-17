import '../../models/app_user.dart';

/// Where a signed-in, active account must go for the "first login: choose
/// your own password" rule, or null if no redirect is needed.
///
/// * An account flagged `mustResetPassword` (created by Admin with a
///   temporary password) is sent to the change-password screen and kept
///   there until it has changed the password.
/// * Anyone else may open the screen voluntarily (Change password in the
///   menu); it is simply allowed.
/// * [enforced] is switched on for every build, so a temporary password must
///   always be changed at first login.
String? passwordGateRedirect({
  required AppUser user,
  required String location,
  required bool enforced,
  required bool changedThisSession,
}) {
  const screen = '/change-password';
  final mustChange = enforced && user.mustResetPassword && !changedThisSession;
  if (mustChange && location != screen) return screen;
  return null;
}

/// Whether the forced change is on for this build (always).
bool get passwordChangeEnforced => true;
