import 'package:flutter/material.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';

/// XBoard 通知工具类
/// 
/// 使用 FlClash 的底部中间 SnackBar 通知（自动消失）
class XBoardNotification {
  XBoardNotification._();

  /// 显示错误通知（底部中间 SnackBar，自动消失）
  static void showError(String message) {
    final context = globalState.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      context.showSnackBar('❌ $message');
    }
  }

  /// 显示成功通知（底部中间 SnackBar，自动消失，绿色）
  static void showSuccess(String message) {
    final context = globalState.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          margin: _getSnackBarMargin(context),
        ),
      );
    }
  }

  /// 显示普通通知（底部中间 SnackBar，自动消失）
  static void showInfo(String message) {
    final context = globalState.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      context.showSnackBar(message);
    }
  }

  /// 显示确认对话框（需要用户确认）
  static Future<bool> showConfirm(
    String message, {
    String? title,
  }) async {
    final result = await globalState.showMessage(
      title: title ?? appLocalizations.tip,
      message: TextSpan(text: message),
      cancelable: true,
    );
    return result == true;
  }

  /// 获取 SnackBar 的 margin（适配屏幕宽度）
  static EdgeInsets _getSnackBarMargin(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return const EdgeInsets.only(bottom: 16, right: 16, left: 16);
    } else {
      return EdgeInsets.only(bottom: 16, left: 16, right: width - 316);
    }
  }
}
