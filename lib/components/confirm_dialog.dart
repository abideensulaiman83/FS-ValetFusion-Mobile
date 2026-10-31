// lib/components/confirm_dialog.dart
//
// Small shared "are you sure?" dialog - used wherever a single tap would otherwise trigger an
// immediate, hard-to-undo action (logging out and losing the current screen's state, deleting
// something, etc.) without the user meaning to. Title, message and labels go through tr(), so
// callers can pass the plain English text (an already-translated string passes through as is).
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

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
      title: Text(tr(context, title)),
      content: Text(tr(context, message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(tr(context, cancelLabel)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive ? TextButton.styleFrom(foregroundColor: context.vf.danger) : null,
          child: Text(tr(context, confirmLabel)),
        ),
      ],
    ),
  );
  return result ?? false;
}
