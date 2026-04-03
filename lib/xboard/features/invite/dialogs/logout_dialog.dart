import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';

class LogoutDialog extends ConsumerWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text(appLocalizations.confirmLogout),
      content: Text(appLocalizations.logoutConfirmMsg),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await _performLogout(context, ref);
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: Text(appLocalizations.logout),
        ),
      ],
    );
  }

  Future<void> _performLogout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(xboardUserProvider.notifier).logout();
      if (context.mounted) {
        XBoardNotification.showSuccess(appLocalizations.loggedOutSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        XBoardNotification.showError(appLocalizations.logoutFailed(e.toString()));
      }
    }
  }
}