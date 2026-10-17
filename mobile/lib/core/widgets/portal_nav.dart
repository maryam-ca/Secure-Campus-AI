import 'package:flutter/material.dart';

/// One page in a portal's menu (e.g. Admin > Library > Catalog, or the
/// Student's "Bus"). Items without a [screen] are shown greyed out and cannot
/// be opened (used for Phase 2 modules that are under development).
class PortalItem {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final int phase;
  final Widget? screen;

  /// Small count shown on the sidebar entry (e.g. unread alerts). 0 hides it.
  final int badge;
  const PortalItem({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.phase = 1,
    this.screen,
    this.badge = 0,
  });

  bool get enabled => screen != null;
}

/// A main module that holds sub-modules. Clicking it opens a first page that
/// lists them (see PortalModulePage) and expands it in the sidebar.
class PortalGroup {
  /// Id of the module's first page. Unique, and different from every item id.
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final int phase;
  final List<PortalItem> items;
  const PortalGroup({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.items,
    this.phase = 1,
  });

  /// Phase 2 modules cannot be opened yet, so they have no first page.
  bool get hasLanding => phase == 1;
}

/// The whole menu of one portal, as data. The sidebar, the header bar and the
/// page shown are all drawn from this, so adding, renaming or moving a module
/// is a change in the portal's nav and nowhere else.
///
/// Order in the sidebar: [home], [topItems], [groups], then [planned].
class PortalNav {
  /// The page opened first and by the logo / Home button.
  final PortalItem home;

  /// Plain pages directly under Home (portals with no sub-modules).
  final List<PortalItem> topItems;
  final List<PortalGroup> groups;

  /// Phase 2 group: listed so the full plan is visible, but not clickable.
  final PortalGroup? planned;
  const PortalNav({
    required this.home,
    this.topItems = const [],
    this.groups = const [],
    this.planned,
  });

  List<PortalGroup> get allGroups => [...groups, ?planned];

  List<PortalItem> get allItems => [
        home,
        ...topItems,
        for (final g in allGroups) ...g.items,
      ];

  /// The openable page with this id, or [home] if unknown or locked.
  PortalItem byId(String id) {
    for (final i in allItems) {
      if (i.id == id && i.enabled) return i;
    }
    return home;
  }

  /// The module whose first page has this id, or null.
  PortalGroup? landingById(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// The group that holds this page id, or null (home and top-level pages).
  PortalGroup? groupOf(String id) {
    for (final g in allGroups) {
      if (g.items.any((i) => i.id == id)) return g;
    }
    return null;
  }
}
