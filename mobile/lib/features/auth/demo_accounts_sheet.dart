import 'package:flutter/material.dart';

import '../../config/demo_accounts.dart';
import '../../core/theme/app_theme.dart';

/// Bottom sheet listing the demo accounts grouped by role. Tapping one pops
/// the sheet with that account; the login screen then signs in with it.
class DemoAccountsSheet extends StatelessWidget {
  final List<DemoAccount> accounts;
  const DemoAccountsSheet({super.key, required this.accounts});

  static const _roleOrder = ['admin', 'librarian', 'security', 'driver', 'student'];

  IconData _icon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'librarian':
        return Icons.local_library_outlined;
      case 'security':
        return Icons.shield_outlined;
      case 'driver':
        return Icons.directions_bus_filled_outlined;
      default:
        return Icons.school_outlined;
    }
  }

  int _rank(String role) {
    final i = _roleOrder.indexOf(role);
    return i < 0 ? _roleOrder.length : i;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...accounts]
      ..sort((a, b) {
        final byRole = _rank(a.role).compareTo(_rank(b.role));
        return byRole != 0 ? byRole : a.label.compareTo(b.label);
      });

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Demo accounts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Testing only. Tap an account to sign in.'),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sorted.length,
                itemBuilder: (ctx, i) {
                  final a = sorted[i];
                  return ListTile(
                    leading: Icon(_icon(a.role), color: AppColors.primaryBlue),
                    title: Text(a.label),
                    subtitle: Text('${a.role} · ${a.email}'),
                    trailing: const Icon(Icons.login),
                    onTap: () => Navigator.pop(ctx, a),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
