// lib/components/confirm_dialog.dart
//
// Small shared "are you sure?" dialog - used wherever a single tap would otherwise trigger an
// immediate, hard-to-undo action (logging out and losing the current screen's state, deleting
// something, etc.) without the user meaning to.
import 'package:flutter/material.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive ? TextButton.styleFrom(foregroundColor: Colors.red.shade700) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
