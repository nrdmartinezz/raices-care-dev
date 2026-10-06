import 'package:flutter/material.dart';

import '../../../core/widgets/app_dialog.dart';

/// The sign-out and delete-account prompts. Returns true when confirmed.
Future<bool> showAccountConfirmDialog(
  BuildContext context, {
  required Widget icon,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: appDialogBarrier,
    builder: (context) => AppDialog(
      icon: icon,
      title: title,
      message: message,
      actions: Row(
        children: [
          Expanded(
            child: AppDialogButton(
              label: 'Cancel',
              filled: false,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppDialogButton(
              label: confirmLabel,
              filled: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}
