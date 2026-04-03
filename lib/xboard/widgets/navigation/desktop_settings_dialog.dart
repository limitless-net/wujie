import 'dart:io';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/theme_dialog.dart';
import 'package:fl_clash/xboard/features/update_check/providers/update_check_provider.dart';
import 'package:fl_clash/xboard/features/update_check/widgets/update_dialog.dart';
import 'package:fl_clash/xboard/features/user_center/dialogs/telegram_dialog.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 桌面端设置弹窗 — 从导航栏底部齿轮按钮唤起
class DesktopSettingsDialog extends ConsumerWidget {
  const DesktopSettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DesktopSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    final tunEnabled = isDesktop
        ? ref.watch(patchClashConfigProvider.select((s) => s.tun.enable))
        : ref.watch(vpnSettingProvider.select((s) => s.systemProxy));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '设置',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // TUN 模式开关
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'TUN 模式',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  tunEnabled ? '已启用 · 全局代理流量' : '已关闭',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                trailing: Switch(
                  value: tunEnabled,
                  onChanged: (value) {
                    if (isDesktop) {
                      ref
                          .read(patchClashConfigProvider.notifier)
                          .updateState(
                            (state) => state.copyWith.tun(enable: value),
                          );
                    } else {
                      ref
                          .read(vpnSettingProvider.notifier)
                          .updateState(
                            (state) => state.copyWith(systemProxy: value),
                          );
                    }
                  },
                ),
              ),

              Divider(
                height: 1,
                indent: 72,
                endIndent: 24,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),

              // 切换主题
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    color: colorScheme.secondary,
                    size: 20,
                  ),
                ),
                title: Text(
                  '切换主题',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '自定义应用外观与配色',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 20,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (context) => const ThemeDialog(),
                  );
                },
              ),

              Divider(
                height: 1,
                indent: 72,
                endIndent: 24,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),

              // Telegram
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Telegram',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '绑定账号 · 加入交流群',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 20,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  TelegramDialog.show(context);
                },
              ),

              Divider(
                height: 1,
                indent: 72,
                endIndent: 24,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),

              // 检查更新
              _DesktopCheckUpdateTile(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 桌面端设置弹窗中的检查更新项
class _DesktopCheckUpdateTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DesktopCheckUpdateTile> createState() =>
      _DesktopCheckUpdateTileState();
}

class _DesktopCheckUpdateTileState
    extends ConsumerState<_DesktopCheckUpdateTile> {
  String _currentVersion = '';
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _currentVersion = info.version);
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      await ref.read(updateCheckProvider.notifier).refresh();
      final updateState = ref.read(updateCheckProvider);
      if (!mounted) return;
      if (updateState.hasUpdate) {
        Navigator.of(context).pop(); // 关闭设置弹窗
        showDialog(
          context: context,
          barrierDismissible: !updateState.forceUpdate,
          builder: (_) => UpdateDialog(state: updateState),
        );
      } else if (updateState.error != null) {
        XBoardNotification.showError('检查更新失败: ${updateState.error}');
      } else {
        XBoardNotification.showSuccess('当前已是最新版本 v$_currentVersion');
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError('检查更新失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.tertiary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.system_update_outlined,
          color: colorScheme.tertiary,
          size: 20,
        ),
      ),
      title: Text(
        '检查更新',
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _currentVersion.isNotEmpty
            ? '当前版本 v$_currentVersion'
            : '正在获取版本...',
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      trailing: _isChecking
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          : Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 20,
            ),
      onTap: _checkForUpdates,
    );
  }
}