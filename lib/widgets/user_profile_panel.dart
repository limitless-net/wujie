import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/auth/models/auth_state.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/theme_dialog.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/logout_dialog.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 侧边栏底部用户资料面板
/// 显示用户邮箱、订阅流量信息、到期时间，以及切换主题和退出登录功能
class UserProfilePanel extends ConsumerWidget {
  const UserProfilePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userInfo = ref.watch(userInfoProvider);
    final subscriptionInfo = ref.watch(subscriptionInfoProvider);
    final authState = ref.watch(xboardUserProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (!authState.isAuthenticated) {
      return _buildNotLoggedIn(context, colorScheme);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 分隔线
          _buildDivider(colorScheme),
          const SizedBox(height: 8),

          // 用户头像 + 邮箱
          _buildUserHeader(context, colorScheme, userInfo, authState),
          const SizedBox(height: 8),

          // 订阅信息（流量 + 到期时间）
          if (subscriptionInfo != null || userInfo != null)
            _buildSubscriptionInfo(context, colorScheme, subscriptionInfo, userInfo),

          const SizedBox(height: 4),

          // 操作按钮（主题 + 登出）
          _buildActions(context, colorScheme),
        ],
      ),
    );
  }

  /// 未登录状态
  Widget _buildNotLoggedIn(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDivider(colorScheme),
          const SizedBox(height: 12),
          Icon(
            Icons.account_circle_outlined,
            size: 32,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            appLocalizations.xboardLoginToViewSubscription,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 分隔线
  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      width: 40,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            colorScheme.outline.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  /// 用户头像 + 邮箱
  Widget _buildUserHeader(
    BuildContext context,
    ColorScheme colorScheme,
    DomainUser? userInfo,
    UserAuthState authState,
  ) {
    final email = userInfo?.email ?? authState.email ?? '---';
    // 取邮箱首字母作为头像
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            email,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 订阅信息（流量 + 到期时间）
  Widget _buildSubscriptionInfo(
    BuildContext context,
    ColorScheme colorScheme,
    DomainSubscription? subscription,
    DomainUser? userInfo,
  ) {
    // 优先从订阅数据获取，回退到用户数据
    final int totalBytes = subscription?.transferLimit ?? userInfo?.transferLimit ?? 0;
    final int usedBytes = (subscription?.totalUsedBytes) ?? userInfo?.totalUsedBytes ?? 0;
    final double usagePercent = totalBytes > 0
        ? (usedBytes / totalBytes).clamp(0.0, 1.0)
        : 0.0;

    // 格式化流量
    final usedStr = _formatBytes(usedBytes);
    final totalStr = _formatBytes(totalBytes);

    // 到期时间
    final expiredAt = subscription?.expiredAt ?? userInfo?.expiredAt;
    String? expiryStr;
    if (expiredAt != null) {
      final remaining = expiredAt.difference(DateTime.now()).inDays;
      if (remaining < 0) {
        expiryStr = appLocalizations.xboardSubscriptionExpired;
      } else if (remaining == 0) {
        expiryStr = '今日到期';
      } else {
        expiryStr = '剩余 $remaining 天';
      }
    }

    // 套餐名称
    final planName = subscription?.planName;

    // 进度条颜色
    Color progressColor;
    if (usagePercent > 0.9) {
      progressColor = Colors.red;
    } else if (usagePercent > 0.7) {
      progressColor = Colors.orange;
    } else {
      progressColor = colorScheme.primary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 套餐名
          if (planName != null && planName.isNotEmpty)
            Text(
              planName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (planName != null && planName.isNotEmpty)
            const SizedBox(height: 4),

          // 流量进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: usagePercent,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 4),

          // 流量文字
          Text(
            '$usedStr / $totalStr',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),

          // 到期时间
          if (expiryStr != null) ...[
            const SizedBox(height: 2),
            Text(
              expiryStr,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: expiredAt != null && expiredAt.isBefore(DateTime.now())
                    ? Colors.red
                    : colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 操作按钮行
  Widget _buildActions(BuildContext context, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Tooltip(
          message: appLocalizations.switchTheme,
          child: IconButton(
            onPressed: () => _showThemeDialog(context),
            icon: Icon(
              Icons.brightness_6,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ),
        Tooltip(
          message: appLocalizations.logout,
          child: IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(
              Icons.logout,
              size: 18,
              color: Colors.red,
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ThemeDialog(),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LogoutDialog(),
    );
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
