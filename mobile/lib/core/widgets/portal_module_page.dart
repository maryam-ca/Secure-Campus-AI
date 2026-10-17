import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'portal_nav.dart';

/// First page of a main module: its sub-modules as cards. Drawn from
/// [PortalNav], so it always matches the sidebar.
class PortalModulePage extends StatelessWidget {
  final PortalGroup group;
  final ValueChanged<String> onOpen;
  const PortalModulePage({super.key, required this.group, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : (constraints.maxWidth >= 420 ? 2 : 1);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${group.items.length} SUB-MODULE${group.items.length == 1 ? '' : 'S'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 92,
              children: [
                for (final i in group.items)
                  _SubModuleCard(item: i, onTap: () => onOpen(i.id)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SubModuleCard extends StatelessWidget {
  final PortalItem item;
  final VoidCallback onTap;
  const _SubModuleCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('card-${item.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentLightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: AppColors.primaryBlueDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.navyText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.bodyText),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.bodyText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
