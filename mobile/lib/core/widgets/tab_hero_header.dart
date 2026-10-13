import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A large icon-badge header for the top of each Student-portal tab -
/// bigger and more present than a small inline section header, since
/// each of these is now the entire content of its own screen. Reuses
/// the same "sheen sweep" language as the login logo (see
/// animated_shield_logo.dart) so the whole app reads as one consistent
/// design system rather than one-off flourishes per screen.
class TabHeroHeader extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const TabHeroHeader({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  State<TabHeroHeader> createState() => _TabHeroHeaderState();
}

class _TabHeroHeaderState extends State<TabHeroHeader> with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _sheen;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();
    _sheen = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final eased = Curves.easeOutBack.transform(_entrance.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: _entrance.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset((1 - eased) * -16, 0), child: child),
        );
      },
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
              ),
              boxShadow: [
                BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 28),
                  AnimatedBuilder(
                    animation: _sheen,
                    builder: (context, _) {
                      final progress = Curves.easeInOutSine.transform(_sheen.value);
                      return Positioned.fill(
                        child: Transform.translate(
                          offset: Offset((progress * 2 - 1) * 70, 0),
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Container(
                              width: 18,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0.0),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21)),
                const SizedBox(height: 2),
                Text(widget.subtitle, style: TextStyle(color: AppColors.bodyText, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}