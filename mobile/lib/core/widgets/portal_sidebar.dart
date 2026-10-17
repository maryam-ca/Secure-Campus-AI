import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'portal_nav.dart';

/// The menu of any portal: Home, plain pages, then main modules that expand
/// and collapse to show their sub-modules, then the Phase 2 group (greyed out,
/// not clickable). Drawn entirely from [PortalNav]; it holds no names itself.
class PortalSidebarMenu extends StatefulWidget {
  final PortalNav nav;
  final String selectedId;
  final ValueChanged<String> onSelect;
  const PortalSidebarMenu({
    super.key,
    required this.nav,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<PortalSidebarMenu> createState() => _PortalSidebarMenuState();
}

class _PortalSidebarMenuState extends State<PortalSidebarMenu> {
  // The open group, by label. Only one is open at a time: opening another
  // closes this one. The group holding the current page is always the one
  // opened, so the highlighted item is never hidden.
  String? _open;

  void _expand(String label) => _open = label;

  @override
  void initState() {
    super.initState();
    _openGroupOf(widget.selectedId);
  }

  @override
  void didUpdateWidget(PortalSidebarMenu old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) _openGroupOf(widget.selectedId);
  }

  void _openGroupOf(String id) {
    final g = widget.nav.landingById(id) ?? widget.nav.groupOf(id);
    if (g != null) _expand(g.label);
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final i in [nav.home, ...nav.topItems])
          _ItemTile(
            item: i,
            selected: widget.selectedId == i.id,
            onTap: i.enabled ? () => widget.onSelect(i.id) : null,
          ),
        if (nav.groups.isNotEmpty) const SizedBox(height: 4),
        for (final g in nav.groups) _groupTile(g),
        if (nav.planned != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _groupTile(nav.planned!),
        ],
      ],
    );
  }

  Widget _groupTile(PortalGroup g) {
    final expanded = _open == g.label;
    final onLanding = widget.selectedId == g.id;
    final holdsSelected = onLanding || g.items.any((i) => i.id == widget.selectedId);
    final planned = g.phase == 2;
    final color = planned
        ? AppColors.bodyText.withValues(alpha: 0.65)
        : (holdsSelected ? AppColors.primaryBlueDark : AppColors.navyText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: onLanding ? AppColors.accentLightBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              // Name: opens the module's first page (its sub-modules) and
              // expands it. Phase 2 has no page, so it only expands.
              Expanded(
                child: InkWell(
                  key: ValueKey('group-${g.label}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (g.hasLanding) {
                      setState(() => _expand(g.label));
                      widget.onSelect(g.id);
                    } else {
                      setState(() => _open = expanded ? null : g.label);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 4, 11),
                    child: Row(
                      children: [
                        Icon(g.icon, size: 22, color: color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: color,
                                ),
                              ),
                              if (planned) const _UnderDevelopmentTag(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Arrow: only expands or collapses the sub-modules.
              InkWell(
                key: ValueKey('toggle-${g.label}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _open = expanded ? null : g.label),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                    color: AppColors.bodyText,
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 4),
                  child: Column(
                    children: [
                      for (final i in g.items)
                        _ItemTile(
                          item: i,
                          sub: true,
                          selected: widget.selectedId == i.id,
                          onTap: i.enabled ? () => widget.onSelect(i.id) : null,
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final PortalItem item;
  final bool selected;
  final bool sub;
  final VoidCallback? onTap;
  const _ItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
    this.sub = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = disabled
        ? AppColors.bodyText.withValues(alpha: 0.5)
        : (selected ? AppColors.primaryBlueDark : AppColors.bodyText);

    return Material(
      color: selected ? AppColors.accentLightBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: ValueKey('nav-${item.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: sub ? 9 : 11),
          child: Row(
            children: [
              Icon(item.icon, size: sub ? 19 : 22, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: sub ? 13.5 : 14.5,
                    fontWeight: selected || !sub ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (item.badge > 0) Badge(label: Text('${item.badge}')),
              if (disabled && sub) Icon(Icons.lock_outline, size: 15, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small "Under development" caption under the Phase 2 group name.
class _UnderDevelopmentTag extends StatelessWidget {
  const _UnderDevelopmentTag();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Under development',
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.warning,
      ),
    );
  }
}
