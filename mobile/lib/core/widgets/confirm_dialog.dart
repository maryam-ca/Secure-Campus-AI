import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows a standard "are you sure?" dialog and returns true only if the
/// person tapped the destructive confirm button. Fixes audit finding §I
/// ("no confirmation dialogs before destructive actions") - use this
/// before deactivating an account, removing a bus assignment, stopping
/// a trip, etc., rather than firing the action directly on tap.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel)),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive ? ElevatedButton.styleFrom(backgroundColor: AppColors.error) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
