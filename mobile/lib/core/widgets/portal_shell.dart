import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'animated_shield_logo.dart';
import 'portal_module_page.dart';
import 'portal_nav.dart';
import 'portal_sidebar.dart';

/// The one layout every portal (Admin, Student, Librarian, Security, Driver)
/// uses: sidebar on the left (a drawer on a phone), a dark blue top bar, a
/// light header bar with the path back to Home, and the page below.
///
/// What differs per role is only the [PortalNav] it is given.
class PortalShell extends ConsumerWidget {
  final PortalNav nav;

  /// Which page is open: an item id, or a module's first-page id. Shared so
  /// dashboard cards and tiles can open pages.
  final StateProvider<String> selection;

  /// Shown under the user's name in the sidebar, e.g. "Administrator".
  final String roleLabel;

  /// Runs (and is awaited, errors ignored) before signing out, so a screen can
  /// finish what it must, e.g. the driver ending a live trip.
  final Future<void> Function()? onBeforeSignOut;

  const PortalShell({
    super.key,
    required this.nav,
    required this.selection,
    required this.roleLabel,
    this.onBeforeSignOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final selectedId = ref.watch(selection);
    void go(String id) => ref.read(selection.notifier).state = id;

    // A main module's own first page (its sub-modules), or a normal page.
    final landing = nav.landingById(selectedId);
    // Locked or unknown ids fall back to Home.
    final item = nav.byId(selectedId);
    final isHome = landing == null && item.id == nav.home.id;
    final group = landing ?? nav.groupOf(item.id);

    final sidebar = Material(
      color: AppColors.cardBackground,
      child: Column(
        children: [
          _SidebarHeader(
            user: ref.watch(currentAppUserProvider).valueOrNull,
            roleLabel: roleLabel,
            onHome: () {
              go(nav.home.id);
              if (!isWide) Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              child: PortalSidebarMenu(
                nav: nav,
                selectedId: landing?.id ?? item.id,
                onSelect: (id) {
                  go(id);
                  if (!isWide) Navigator.of(context).pop();
                },
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.lock_reset),
                    title: const Text('Change password'),
                    onTap: () {
                      if (!isWide) Navigator.of(context).pop();
                      GoRouter.of(context).push('/change-password');
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Sign out', style: TextStyle(color: AppColors.error)),
                    onTap: () async {
                      try {
                        await onBeforeSignOut?.call();
                      } catch (_) {
                        // never block signing out
                      }
                      await ref.read(authServiceProvider).signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final body = Scaffold(
      appBar: AppBar(
        // Two lines: which app and portal this is, then the page.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SecureCampus  ·  $roleLabel Portal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            Text(
              landing?.label ?? item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (!isHome)
            IconButton(
              key: const ValueKey('home-button'),
              tooltip: 'Back to ${nav.home.label}',
              icon: const Icon(Icons.home_outlined),
              onPressed: () => go(nav.home.id),
            ),
        ],
      ),
      drawer: isWide ? null : Drawer(child: sidebar),
      body: Column(
        children: [
          // The header bar, the same on every page except Home (which has its
          // own greeting card): a clickable path back up
          // (Home > module > page), what the page is for, and the module's
          // sub-modules to switch between.
          if (!isHome)
            _HeaderBar(
              home: nav.home,
              group: group,
              item: landing == null ? item : null,
              description: landing?.description ?? item.description,
              onGo: go,
            ),
          Expanded(
            child: landing != null
                ? PortalModulePage(group: landing, onOpen: go)
                : KeyedSubtree(key: ValueKey(item.id), child: item.screen!),
          ),
        ],
      ),
    );

    if (!isWide) return body;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 270, child: sidebar),
          const VerticalDivider(width: 1, color: AppColors.divider),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Branded block at the top of the sidebar: logo, app name, who is signed in
/// and their role. Same solid colour as the top bar. Tapping the logo or the
/// name goes back to Home.
class _SidebarHeader extends StatelessWidget {
  final AppUser? user;
  final String roleLabel;
  final VoidCallback onHome;
  const _SidebarHeader({this.user, required this.roleLabel, required this.onHome});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : roleLabel;
    final email = user?.email ?? '';

    return Container(
      width: double.infinity,
      color: AppColors.primaryBlueDark,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const ValueKey('brand-home'),
            borderRadius: BorderRadius.circular(10),
            onTap: onHome,
            child: Row(
              children: [
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
          ),
          const SizedBox(height: 16),
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
            child: Text(roleLabel,
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Header bar shown on every page except Home. Home and the module name are
/// clickable, so every page has a way back up. When the module has several
/// sub-modules they appear as chips to switch between them.
class _HeaderBar extends StatelessWidget {
  final PortalItem home;
  final PortalGroup? group;
  final PortalItem? item; // null on a module's first page
  final String description;
  final ValueChanged<String> onGo;
  const _HeaderBar({
    required this.home,
    required this.group,
    required this.item,
    required this.description,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context) {
    const crumbStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryBlueDark,
    );
    const sep = Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('›', style: crumbStyle),
    );

    Widget crumb(String label, String id, Key key) => InkWell(
          key: key,
          onTap: () => onGo(id),
          child: Text(
            label,
            style: crumbStyle.copyWith(decoration: TextDecoration.underline),
          ),
        );

    final current = item;
    final siblings = (group != null && current != null && group!.items.length > 1)
        ? group!.items
        : const <PortalItem>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.accentLightBlue,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              crumb('Home', home.id, const ValueKey('crumb-home')),
              if (group != null) ...[
                sep,
                if (current == null)
                  Text(group!.label, style: crumbStyle)
                else
                  crumb(group!.label, group!.id, const ValueKey('crumb-group')),
              ],
              if (current != null) ...[
                sep,
                Text(current.label, style: crumbStyle),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.bodyText),
          ),
          if (siblings.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in siblings)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('chip-${s.id}'),
                        label: Text(s.label),
                        selected: s.id == current!.id,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => onGo(s.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
