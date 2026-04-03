import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show XBoardSDK;
import 'package:url_launcher/url_launcher.dart';

/// Telegram 绑定与加群对话框
class TelegramDialog extends ConsumerStatefulWidget {
  const TelegramDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TelegramDialog(),
    );
  }

  @override
  ConsumerState<TelegramDialog> createState() => _TelegramDialogState();
}

class _TelegramDialogState extends ConsumerState<TelegramDialog> {
  bool _loading = true;
  String? _botUsername;
  String? _discussLink;
  bool _isTelegramEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTelegramInfo();
  }

  Future<void> _loadTelegramInfo() async {
    try {
      final httpService = XBoardSDK.instance.httpService;

      // 并行请求 Bot 信息和通讯配置
      final results = await Future.wait([
        httpService
            .getRequest('/api/v1/user/telegram/getBotInfo')
            .catchError((_) => <String, dynamic>{}),
        httpService
            .getRequest('/api/v1/user/comm/config')
            .catchError((_) => <String, dynamic>{}),
      ]);

      final botData = results[0]['data'] as Map<String, dynamic>?;
      final commData = results[1]['data'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _botUsername = botData?['username'] as String?;
          _isTelegramEnabled =
              (commData?['is_telegram'] as int? ?? 0) == 1;
          _discussLink = commData?['telegram_discuss_link'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(userInfoProvider);
    final subscription = ref.watch(subscriptionInfoProvider);
    final isBound =
        user?.telegramId != null && user!.telegramId!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0088CC).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF0088CC),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Telegram',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          isBound ? '已绑定' : '未绑定',
                          style: textTheme.labelSmall?.copyWith(
                            color: isBound
                                ? Colors.green
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 绑定状态指示
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBound
                          ? Colors.green.withValues(alpha: 0.1)
                          : colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isBound ? 'ID: ${user!.telegramId}' : '未绑定',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isBound
                            ? Colors.green.shade700
                            : colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 关闭按钮
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 加载中
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),

              // 错误提示
              if (!_loading && _error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '无法获取 Telegram 信息',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 内容区
              if (!_loading && _error == null) ...[
                // 绑定区
                if (!isBound && _isTelegramEnabled && _botUsername != null) ...[
                  _SectionCard(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    icon: Icons.link_rounded,
                    iconColor: const Color(0xFF0088CC),
                    title: '绑定账号',
                    description: '通过 Telegram Bot 绑定您的账号，即可接收到期提醒、流量预警和每日签到领流量等功能。',
                    children: [
                      const SizedBox(height: 12),
                      // 复制绑定命令
                      _ActionButton(
                        icon: Icons.content_copy_rounded,
                        label: '复制绑定命令',
                        color: colorScheme.primary,
                        onTap: () {
                          final url = subscription?.subscribeUrl ?? '';
                          if (url.isEmpty) {
                            XBoardNotification.showError('未找到订阅链接');
                            return;
                          }
                          Clipboard.setData(
                              ClipboardData(text: '/bind $url'));
                          XBoardNotification.showSuccess(
                              '已复制绑定命令，请发送给 Bot');
                        },
                      ),
                      const SizedBox(height: 8),
                      // 打开 Bot
                      _ActionButton(
                        icon: Icons.open_in_new_rounded,
                        label: '打开 Telegram Bot',
                        color: const Color(0xFF0088CC),
                        onTap: () => _openUrl(
                            'https://t.me/$_botUsername'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 已绑定 — 可打开 Bot
                if (isBound && _botUsername != null) ...[
                  _SectionCard(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    icon: Icons.smart_toy_outlined,
                    iconColor: const Color(0xFF0088CC),
                    title: 'Telegram Bot',
                    description: '已绑定，可使用签到、查流量、查节点等 Bot 功能。',
                    children: [
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.open_in_new_rounded,
                        label: '打开 Bot (@$_botUsername)',
                        color: const Color(0xFF0088CC),
                        onTap: () => _openUrl(
                            'https://t.me/$_botUsername'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 如果未启用 TG Bot
                if (!_isTelegramEnabled) ...[
                  _SectionCard(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.grey,
                    title: '未启用',
                    description: '站点暂未开启 Telegram Bot 功能。',
                    children: const [],
                  ),
                  const SizedBox(height: 12),
                ],

                // 加群区
                if (_discussLink != null && _discussLink!.isNotEmpty) ...[
                  _SectionCard(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    icon: Icons.group_rounded,
                    iconColor: Colors.green,
                    title: '加入交流群',
                    description: '加入 Telegram 群组，获取最新公告、参与讨论和获得技术支持。',
                    children: [
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.group_add_rounded,
                        label: '加入 Telegram 群',
                        color: Colors.green,
                        onTap: () => _openUrl(_discussLink!),
                      ),
                    ],
                  ),
                ],
              ],


            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        XBoardNotification.showError('无法打开链接');
      }
    } catch (e) {
      XBoardNotification.showError('打开链接失败: $e');
    }
  }
}

/// 区域卡片
class _SectionCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<Widget> children;

  const _SectionCard({
    required this.colorScheme,
    required this.textTheme,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
      ),
    );
  }
}
