import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'animated_shield_logo.dart';

/// Building blocks shared by the Admin and Student home screens, so both look
/// like one app: a white header card with the real logo, a "Needs attention"
/// list, compact number tiles and a wide status tile.

/// White card: the SecureCampus shield (still), the app name, a bold [title]
/// and a quieter [subtitle].
class BrandHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const BrandHeaderCard({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: AppColors.navyText.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const AnimatedShieldLogo(size: 46, animate: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SecureCampus',
                  style: TextStyle(color: AppColors.primaryBlue, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.navyText, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.bodyText, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AttentionItem {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;
  const AttentionItem({required this.icon, required this.color, required this.text, required this.onTap});
}

/// Only what needs action, one slim tappable row each; a green "All clear"
/// when there is nothing.
class AttentionPanel extends StatelessWidget {
  final List<AttentionItem> items;
  const AttentionPanel({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('All clear - nothing needs attention.',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6, left: 2),
          child: Text('Needs attention',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.navyText)),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: item.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.color.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: item.color, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                      Icon(Icons.chevron_right, color: item.color, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A compact tappable number tile: tinted icon, big [value], [label], and an
/// optional one-line [note]. Fixed content size, so it cannot overflow.
class StatTile extends StatelessWidget {
  final String label;
  final String? note;
  final String value;
  final IconData icon;
  final Color color;
  final Color? noteColor;
  final VoidCallback onTap;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.note,
    this.noteColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.navyText, height: 1.1)),
                    ),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.bodyText, height: 1.2)),
                    if (note != null)
                      Text(note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: noteColor ?? color, fontWeight: FontWeight.w600, height: 1.2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width tile for one line of status text (the bus).
class WideStatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color color;
  final VoidCallback onTap;
  const WideStatusTile({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.bodyText)),
                    Text(text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color == AppColors.bodyText ? AppColors.navyText : color)),
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
