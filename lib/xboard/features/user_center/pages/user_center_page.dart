import 'dart:io';
import 'dart:math' as math;
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/auth/dialogs/login_dialog.dart';
import 'package:fl_clash/xboard/features/auth/dialogs/register_dialog.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/theme_dialog.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/logout_dialog.dart';
import 'package:fl_clash/xboard/features/user_center/dialogs/order_management_dialog.dart';
import 'package:fl_clash/xboard/features/user_center/dialogs/telegram_dialog.dart';
import 'package:fl_clash/xboard/features/user_center/dialogs/help_center_dialog.dart';
import 'package:fl_clash/xboard/features/invite/widgets/qr_code_widget.dart';
import 'package:fl_clash/xboard/features/update_check/providers/update_check_provider.dart';
import 'package:fl_clash/xboard/features/update_check/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart'
    show UserModel, SubscriptionModel, XBoardSDK;
import 'package:intl/intl.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/services/storage/xboard_storage_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ╔══════════════════════════════════════════════════════════════╗
// ║  个人中心页面 V4 — 分区分明 · 动画刷新 · 高对比              ║
// ╚══════════════════════════════════════════════════════════════╝

class UserCenterPage extends ConsumerStatefulWidget {
  const UserCenterPage({super.key});

  @override
  ConsumerState<UserCenterPage> createState() => _UserCenterPageState();
}

class _UserCenterPageState extends ConsumerState<UserCenterPage>
    with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  late final AnimationController _refreshSpinCtrl;

  @override
  void initState() {
    super.initState();
    _refreshSpinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 游客模式不需要刷新用户数据
      final authState = ref.read(xboardUserProvider);
      if (authState.isAuthenticated) {
        _doRefresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshSpinCtrl.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    if (_isRefreshing) return;
    // 游客模式不刷新
    final authState = ref.read(xboardUserProvider);
    if (!authState.isAuthenticated) return;
    setState(() => _isRefreshing = true);
    _refreshSpinCtrl.repeat();

    final storageService = ref.read(storageServiceProvider);
    try {
      try {
        final userModel = await XBoardSDK.instance.user.getUserInfo();
        final userInfo = _mapUserModel(userModel);
        ref.read(userInfoProvider.notifier).state = userInfo;
        await storageService.saveDomainUser(userInfo);
      } catch (_) {}
      try {
        final subModel =
            await XBoardSDK.instance.subscription.getSubscription();
        final sub = _mapSubscriptionModel(subModel);
        ref.read(subscriptionInfoProvider.notifier).state = sub;
        await storageService.saveDomainSubscription(sub);
      } catch (_) {}
      if (mounted) {
        XBoardNotification.showSuccess('数据已刷新');
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError('刷新失败: $e');
      }
    } finally {
      _refreshSpinCtrl.stop();
      _refreshSpinCtrl.reset();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(xboardUserProvider);
    
    // 未登录状态显示游客引导页
    if (!authState.isAuthenticated) {
      return _buildGuestView(context);
    }

    final userInfo = ref.watch(userInfoProvider);
    final subscription = ref.watch(subscriptionInfoProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final topPad = isDesktop ? 16.0 : MediaQuery.of(context).padding.top + 12;
    final bottomPad =
        isDesktop ? 24.0 : MediaQuery.of(context).viewPadding.bottom + 90;

    final expiredAt = subscription?.expiredAt ?? userInfo?.expiredAt;
    final bool isExpired =
        expiredAt != null && expiredAt.isBefore(DateTime.now());
    final bool nearExpiry = !isExpired &&
        expiredAt != null &&
        expiredAt.difference(DateTime.now()).inDays <= 3;

    // ── 页面背景：浅色用明显灰底，暗色用 primary 染色渐变
    final pageBg = isDark
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primary.withValues(alpha: 0.06),
                colorScheme.surface,
                colorScheme.surface,
              ],
            ),
          )
        : BoxDecoration(
            color: colorScheme.surfaceContainerLow,
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: pageBg,
        child: RefreshIndicator(
          onRefresh: _doRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: topPad,
              bottom: bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 标题 + 刷新按钮 ───
                _buildTitleBar(colorScheme),
                const SizedBox(height: 16),

                // ─── 1. 账户信息 + 流量（英雄卡） ───
                _ProfileCard(
                  userInfo: userInfo,
                  subscription: subscription,
                  isRefreshing: _isRefreshing,
                  onRefresh: _doRefresh,
                  refreshAnimation: _refreshSpinCtrl,
                ),
                const SizedBox(height: 16),

                // ─── 2. 续费横幅 ───
                if (isExpired) ...[
                  _RenewalBanner(
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red.shade600,
                    bgColor: Colors.red.withValues(alpha: 0.06),
                    borderColor: Colors.red.withValues(alpha: 0.2),
                    title: '您的订阅已过期，代理服务已停止',
                    titleColor: Colors.red.shade700,
                    buttonText: '续费套餐',
                    buttonColor: Colors.red.shade600,
                  ),
                  const SizedBox(height: 16),
                ] else if (nearExpiry) ...[
                  _RenewalBanner(
                    icon: Icons.access_time_rounded,
                    iconColor: Colors.orange.shade700,
                    bgColor: Colors.orange.withValues(alpha: 0.06),
                    borderColor: Colors.orange.withValues(alpha: 0.2),
                    title: expiredAt!.difference(DateTime.now()).inHours < 24
                        ? '您的订阅今日到期，请尽快续费'
                        : '您的订阅将在 ${expiredAt.difference(DateTime.now()).inDays} 天后到期',
                    titleColor: Colors.orange.shade800,
                    buttonText: '立即续费',
                    buttonColor: Colors.orange.shade700,
                  ),
                  const SizedBox(height: 16),
                ],

                // ─── 3. 功能入口 ───
                const SizedBox(height: 20),
                _sectionHeader(context, Icons.apps_rounded, '功能'),
                const SizedBox(height: 8),
                _FunctionsGroup(),
                const SizedBox(height: 20),

                // ─── 4. 系统设置 ───
                _sectionHeader(context, Icons.settings_rounded, '系统'),
                const SizedBox(height: 8),
                _SettingsGroup(),
                const SizedBox(height: 24),

                // ─── 5. 退出 ───
                _LogoutButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 游客引导页 — 未登录时显示
  Widget _buildGuestView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final topPad = isDesktop ? 16.0 : MediaQuery.of(context).padding.top + 12;
    final bottomPad = isDesktop ? 24.0 : MediaQuery.of(context).viewPadding.bottom + 90;

    final pageBg = isDark
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primary.withValues(alpha: 0.06),
                colorScheme.surface,
                colorScheme.surface,
              ],
            ),
          )
        : BoxDecoration(color: colorScheme.surfaceContainerLow);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: pageBg,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: topPad, bottom: bottomPad, left: 32, right: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 56,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '个人中心',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '登录后可查看账户信息、管理订阅、\n邀请好友等更多功能',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => LoginDialog.show(context),
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text(
                      '登录账号',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await RegisterDialog.show(context);
                  },
                  child: Text(
                    '没有账号？立即注册',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        '个人中心',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
      ),
    );
  }

  Widget _sectionHeader(
      BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 15, color: colorScheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  账户 + 流量 英雄卡                                         ║
// ╚══════════════════════════════════════════════════════════════╝

class _ProfileCard extends StatelessWidget {
  final DomainUser? userInfo;
  final DomainSubscription? subscription;
  final bool isRefreshing;
  final VoidCallback? onRefresh;
  final Animation<double>? refreshAnimation;
  const _ProfileCard({
    this.userInfo,
    this.subscription,
    this.isRefreshing = false,
    this.onRefresh,
    this.refreshAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final email = userInfo?.email ?? '---';
    final initial =
        email.isNotEmpty && email != '---' ? email[0].toUpperCase() : '?';
    final planName = subscription?.planName;

    final expiredAt = subscription?.expiredAt ?? userInfo?.expiredAt;
    final bool isExpired =
        expiredAt != null && expiredAt.isBefore(DateTime.now());

    // ── 流量计算
    final int totalBytes =
        subscription?.transferLimit ?? userInfo?.transferLimit ?? 0;
    final int uploadBytes =
        subscription?.uploadedBytes ?? userInfo?.uploadedBytes ?? 0;
    final int downloadBytes =
        subscription?.downloadedBytes ?? userInfo?.downloadedBytes ?? 0;
    final int usedBytes = uploadBytes + downloadBytes;
    final double usagePercent = isExpired
        ? 0.0
        : (totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0);

    Color progressColor;
    if (usagePercent > 0.9) {
      progressColor = Colors.red;
    } else if (usagePercent > 0.7) {
      progressColor = Colors.orange;
    } else {
      progressColor = colorScheme.primary;
    }

    // ── 到期信息
    String expiryText;
    Color expiryColor;
    if (expiredAt == null) {
      expiryText = appLocalizations.infiniteTime;
      expiryColor = Colors.green;
    } else if (isExpired) {
      expiryText = appLocalizations.xboardSubscriptionExpired;
      expiryColor = Colors.red;
    } else {
      final days = expiredAt.difference(DateTime.now()).inDays;
      expiryText = '剩余 $days 天';
      expiryColor = days <= 7 ? Colors.orange : Colors.green;
    }

    // ── 余额 / 佣金
    final balance =
        '¥${userInfo?.balanceInYuan.toStringAsFixed(2) ?? '0.00'}';
    final commission =
        '¥${userInfo?.commissionBalanceInYuan.toStringAsFixed(2) ?? '0.00'}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: const Alignment(-1, -0.6),
          end: const Alignment(1, 1),
          colors: [
            colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            colorScheme.primary.withValues(alpha: isDark ? 0.04 : 0.0),
          ],
        ),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 第1行：头像 + 邮箱
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(colorScheme.primary, Colors.white, 0.3)!,
                        colorScheme.primary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        isDark ? colorScheme.surface : Colors.white,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 刷新按钮
                RotationTransition(
                  turns: refreshAnimation ?? const AlwaysStoppedAnimation(0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isRefreshing ? null : onRefresh,
                      borderRadius: BorderRadius.circular(10),
                      hoverColor: colorScheme.primary
                          .withValues(alpha: isDark ? 0.10 : 0.06),
                      splashColor:
                          colorScheme.primary.withValues(alpha: 0.12),
                      child: Tooltip(
                        message: '刷新数据',
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : colorScheme.primary
                                    .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.sync_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── 第2行：套餐 + 到期标签
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (planName != null)
                  _MiniTag(
                    text: planName,
                    color: colorScheme.primary,
                    isDark: isDark,
                  ),
                _MiniTag(
                  text: expiryText,
                  color: expiryColor,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── 流量进度条（百分比叠在条内）
            Stack(
              alignment: Alignment.centerRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: usagePercent,
                    minHeight: 16,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : colorScheme.primary.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '${(usagePercent * 100).toStringAsFixed(1)}%',
                    style: textTheme.labelSmall?.copyWith(
                      color: usagePercent > 0.5 ? Colors.white : progressColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            // ── 余额 + 佣金
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.account_balance_wallet_outlined,
                  text: '余额 $balance',
                  color: Colors.purple.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 14),
                _InfoChip(
                  icon: Icons.currency_yuan,
                  text: '佣金 $commission',
                  color: Colors.teal.withValues(alpha: 0.8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String text;
  const _InfoItem(this.icon, this.text);
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  数据概览 — 2×2 小卡片（带独立色调背景）                     ║
// ╚══════════════════════════════════════════════════════════════╝

class _StatsGrid extends StatelessWidget {
  final DomainUser? userInfo;
  final DomainSubscription? subscription;
  const _StatsGrid({this.userInfo, this.subscription});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final balance =
        '¥${userInfo?.balanceInYuan.toStringAsFixed(2) ?? '0.00'}';
    final commission =
        '¥${userInfo?.commissionBalanceInYuan.toStringAsFixed(2) ?? '0.00'}';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.account_balance_wallet_rounded,
            label: '余额',
            value: balance,
            accentColor: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.monetization_on_rounded,
            label: '佣金',
            value: commission,
            accentColor: colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? colorScheme.surfaceContainerLow
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        hoverColor: accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
        splashColor: accentColor.withValues(alpha: 0.10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? accentColor.withValues(alpha: 0.10)
                  : accentColor.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : accentColor.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                      alpha: isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  功能入口组（邀请 / Telegram / 订单管理）                    ║
// ╚══════════════════════════════════════════════════════════════╝

class _FunctionsGroup extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return _GroupContainer(
      child: Column(
        children: [
          _GroupTile(
            icon: Icons.assignment_rounded,
            iconColor: const Color(0xFF1565C0),
            title: '订阅信息',
            subtitle: '查看套餐详情与订阅二维码',
            onTap: () => _SubscriptionInfoDialog.show(context, ref),
          ),
          _groupDivider(colorScheme),
          _GroupTile(
            icon: Icons.card_giftcard_rounded,
            iconColor: colorScheme.primary,
            title: '邀请好友',
            subtitle: '邀请返佣，共同受益',
            onTap: () => GoRouter.of(context).go('/invite'),
          ),
          _groupDivider(colorScheme),
          _GroupTile(
            icon: Icons.send_rounded,
            iconColor: const Color(0xFF2AABEE),
            title: 'Telegram',
            subtitle: '加入交流群获取最新动态',
            onTap: () => TelegramDialog.show(context),
          ),
          _groupDivider(colorScheme),
          _GroupTile(
            icon: Icons.receipt_long_rounded,
            iconColor: colorScheme.secondary,
            title: '订单管理',
            subtitle: '查看历史订单与续费记录',
            onTap: () => OrderManagementDialog.show(context),
          ),
          _groupDivider(colorScheme),
          _GroupTile(
            icon: Icons.help_outline_rounded,
            iconColor: Colors.orange,
            title: '帮助中心',
            subtitle: '常见问题与使用教程',
            onTap: () => HelpCenterDialog.show(context),
          ),
        ],
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  订阅信息弹窗                                                ║
// ╚══════════════════════════════════════════════════════════════╝

class _SubscriptionInfoDialog extends ConsumerWidget {
  const _SubscriptionInfoDialog();

  static bool _isShowing = false;

  static void show(BuildContext context, WidgetRef ref) {
    if (_isShowing) return;
    _isShowing = true;
    // 后台静默刷新，不阻塞弹窗打开
    ref.read(xboardUserProvider.notifier).refreshSubscriptionData();
    showDialog(
      context: context,
      builder: (_) => const _SubscriptionInfoDialog(),
    ).whenComplete(() => _isShowing = false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userInfo = ref.watch(userInfoProvider);
    final subscription = ref.watch(subscriptionInfoProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 500 ? 420.0 : screenWidth - 48.0;

    // 检测是否有有效套餐
    final bool hasPlan = (subscription?.planId ?? 0) > 0 ||
        (userInfo?.planId != null && userInfo!.planId! > 0);

    final planName = subscription?.planName ?? '未知套餐';
    final expiredAt = subscription?.expiredAt ?? userInfo?.expiredAt;
    final int totalBytes =
        subscription?.transferLimit ?? userInfo?.transferLimit ?? 0;
    final int uploadBytes =
        subscription?.uploadedBytes ?? userInfo?.uploadedBytes ?? 0;
    final int downloadBytes =
        subscription?.downloadedBytes ?? userInfo?.downloadedBytes ?? 0;
    final int usedBytes = uploadBytes + downloadBytes;
    final int remainingBytes =
        totalBytes > usedBytes ? totalBytes - usedBytes : 0;
    final bool isExpired =
        expiredAt != null && expiredAt.isBefore(DateTime.now());
    final bool trafficExhausted = totalBytes > 0 && usedBytes >= totalBytes;
    final double usagePercent = isExpired
        ? 0.0
        : (totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0);

    Color progressColor;
    if (usagePercent > 0.9) {
      progressColor = Colors.red;
    } else if (usagePercent > 0.7) {
      progressColor = Colors.orange;
    } else {
      progressColor = colorScheme.primary;
    }

    String expiryText;
    Color expiryColor;
    if (expiredAt == null) {
      expiryText = '长期有效';
      expiryColor = Colors.green;
    } else if (isExpired) {
      expiryText = '已过期';
      expiryColor = Colors.red;
    } else {
      final days = expiredAt.difference(DateTime.now()).inDays;
      expiryText =
          '剩余 $days 天 (${DateFormat('yyyy-MM-dd').format(expiredAt)})';
      expiryColor = days <= 7 ? Colors.orange : Colors.green;
    }

    final subscribeUrl = subscription?.subscribeUrl ?? '';
    final bool needRenew = isExpired || trafficExhausted;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.assignment_rounded,
                      size: 20, color: const Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Text(
                    '订阅信息',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // ── 内容
            if (!hasPlan) ...[
              // 未购买套餐 — 引导购买
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 48,
                        color: colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      '未购买套餐',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '您当前没有订阅套餐，请前往购买以使用代理服务。',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          GoRouter.of(context).go('/plans');
                        },
                        icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                        label: const Text('购买套餐'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 套餐 + 到期
                    _infoRow(Icons.card_membership_rounded, '套餐名称',
                        planName, colorScheme.primary, colorScheme),
                    _infoRow(
                        Icons.schedule_rounded,
                        '到期时间',
                        expiryText,
                        expiryColor,
                        colorScheme),

                    // ── 过期/流量耗尽提示
                    if (needRenew) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 18, color: Colors.red.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isExpired
                                    ? '您的套餐已过期，代理服务已停止'
                                    : '流量已用完，代理服务已停止',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // ── 流量概览标题
                    Text(
                      '流量概览',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── 流量进度条
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: usagePercent,
                            minHeight: 20,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : colorScheme.primary
                                    .withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                progressColor),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${(usagePercent * 100).toStringAsFixed(1)}%',
                            style: textTheme.labelSmall?.copyWith(
                              color: usagePercent > 0.45
                                  ? Colors.white
                                  : progressColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // ── 已用 / 剩余 / 总量
                    Row(
                      children: [
                        Expanded(
                          child: _trafficStatCard(
                            label: '已用流量',
                            value: _formatBytes(isExpired ? 0 : usedBytes),
                            icon: Icons.data_usage_rounded,
                            color: progressColor,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _trafficStatCard(
                            label: '剩余流量',
                            value: _formatBytes(
                                isExpired ? 0 : remainingBytes),
                            icon: Icons.battery_charging_full_rounded,
                            color: Colors.green,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _trafficStatCard(
                            label: '总流量',
                            value: _formatBytes(
                                isExpired ? 0 : totalBytes),
                            icon: Icons.cloud_outlined,
                            color: colorScheme.primary,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // ── 上传流量（独占一行）
                    _trafficDetailRow(
                      icon: Icons.cloud_upload_outlined,
                      label: '上传流量',
                      value: _formatBytes(isExpired ? 0 : uploadBytes),
                      color: const Color(0xFF1565C0),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    // ── 下载流量（独占一行）
                    _trafficDetailRow(
                      icon: Icons.cloud_download_outlined,
                      label: '下载流量',
                      value: _formatBytes(isExpired ? 0 : downloadBytes),
                      color: Colors.green,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 16),
                    // ── 其他信息
                    if (subscription?.speedLimit != null &&
                        subscription!.speedLimit! > 0)
                      _infoRow(Icons.speed_rounded, '速率限制',
                          '${subscription!.speedLimit} Mbps',
                          Colors.orange, colorScheme),
                    if (subscription?.deviceLimit != null &&
                        subscription!.deviceLimit! > 0)
                      _infoRow(Icons.devices_rounded, '设备限制',
                          '${subscription!.deviceLimit} 台',
                          Colors.teal, colorScheme),
                    if (subscription?.nextResetAt != null)
                      _infoRow(
                          Icons.event_repeat_rounded,
                          '流量重置',
                          DateFormat('yyyy-MM-dd')
                              .format(subscription!.nextResetAt!),
                          const Color(0xFF1565C0),
                          colorScheme),
                    if (userInfo?.discount != null &&
                        userInfo!.discount! > 0)
                      _infoRow(
                          Icons.discount_rounded,
                          '专属折扣',
                          '${(userInfo!.discount! * 100).toStringAsFixed(0)}%',
                          Colors.deepPurple,
                          colorScheme),

                    // ── 续费按钮
                    if (needRenew) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            GoRouter.of(context).go('/subscription');
                          },
                          icon: const Icon(Icons.shopping_cart_rounded,
                              size: 18),
                          label: Text(isExpired ? '立即续费' : '购买流量'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ── 订阅二维码按钮
                    if (subscribeUrl.isNotEmpty) ...[
                      SizedBox(height: needRenew ? 10 : 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showQrDialog(context, subscribeUrl),
                          icon: const Icon(Icons.qr_code_rounded,
                              size: 18),
                          label: const Text('查看订阅二维码'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _trafficStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trafficDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color iconColor,
      ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(BuildContext context, String url) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '订阅二维码',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '请使用支持的客户端扫码导入',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 16),
                QrCodeWidget(data: url, size: 220),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  系统设置组                                                  ║
// ╚══════════════════════════════════════════════════════════════╝

class _SettingsGroup extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return _GroupContainer(
      child: Column(
        children: [
          _TunToggleTile(ref: ref),
          _groupDivider(colorScheme),
          _GroupTile(
            icon: Icons.palette_rounded,
            iconColor: colorScheme.tertiary,
            title: appLocalizations.switchTheme,
            subtitle: '自定义应用外观与配色',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const ThemeDialog(),
              );
            },
          ),
          _groupDivider(colorScheme),
          _CheckUpdateTile(),
        ],
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  退出登录                                                   ║
// ╚══════════════════════════════════════════════════════════════╝

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GroupContainer(
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const LogoutDialog(),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 18,
                color: Colors.red.withValues(alpha: isDark ? 0.7 : 0.85),
              ),
              const SizedBox(width: 8),
              Text(
                appLocalizations.logout,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red.withValues(alpha: isDark ? 0.7 : 0.85),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  通用容器 + 通用列表项                                      ║
// ╚══════════════════════════════════════════════════════════════╝

/// 分组容器 — 统一样式，浅色纯白 + 暗色 surfaceContainerLow
class _GroupContainer extends StatelessWidget {
  final Widget child;
  const _GroupContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.10)
              : colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 组内列表项
class _GroupTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GroupTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.03),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            iconColor.withValues(alpha: 0.85),
                            Color.lerp(iconColor, Colors.black, 0.15)!,
                          ]
                        : [
                            Color.lerp(iconColor, Colors.white, 0.25)!,
                            iconColor,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: isDark ? 0.15 : 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _groupDivider(ColorScheme colorScheme) {
  return Divider(
    height: 1,
    indent: 62,
    endIndent: 16,
    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
  );
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  小组件                                                     ║
// ╚══════════════════════════════════════════════════════════════╝

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;
  const _MiniTag(
      {required this.text, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

/// 流量仪表盘画笔
class _TrafficGaugePainter extends CustomPainter {
  final double percent;
  final Color progressColor;
  final Color trackColor;
  final double strokeWidth;

  _TrafficGaugePainter({
    required this.percent,
    required this.progressColor,
    required this.trackColor,
    this.strokeWidth = 10,
  });

  static const double _startAngle = 2.3562; // 135°
  static const double _totalSweep = 4.7124; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth - 2) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _totalSweep, false, trackPaint);

    if (percent > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, _startAngle,
          _totalSweep * percent.clamp(0.0, 1.0), false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrafficGaugePainter old) =>
      old.percent != percent ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// 续费引导横幅
class _RenewalBanner extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final Color titleColor;
  final String buttonText;
  final Color buttonColor;

  const _RenewalBanner({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.titleColor,
    required this.buttonText,
    required this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final isDesktop =
                    Platform.isLinux || Platform.isWindows || Platform.isMacOS;
                if (isDesktop) {
                  GoRouter.of(context).go('/plans');
                } else {
                  GoRouter.of(context).push('/plans');
                }
              },
              icon: const Icon(Icons.shopping_cart_outlined, size: 16),
              label: Text(buttonText),
              style: FilledButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  TUN 开关 / 检查更新                                        ║
// ╚══════════════════════════════════════════════════════════════╝

class _TunToggleTile extends ConsumerWidget {
  final WidgetRef ref;
  const _TunToggleTile({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final tunEnabled = isDesktop
        ? ref.watch(patchClashConfigProvider.select((s) => s.tun.enable))
        : ref.watch(vpnSettingProvider.select((s) => s.systemProxy));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final newVal = !tunEnabled;
          if (isDesktop) {
            ref.read(patchClashConfigProvider.notifier).updateState(
                  (state) => state.copyWith.tun(enable: newVal),
                );
          } else {
            ref.read(vpnSettingProvider.notifier).updateState(
                  (state) => state.copyWith(systemProxy: newVal),
                );
          }
        },
        hoverColor: colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.03),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(colorScheme.primary, Colors.white,
                          isDark ? 0.15 : 0.25)!,
                      colorScheme.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TUN 模式',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tunEnabled ? '已启用 · 全局代理流量' : '已关闭',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: tunEnabled,
                onChanged: (value) {
                  if (isDesktop) {
                    ref.read(patchClashConfigProvider.notifier).updateState(
                          (state) => state.copyWith.tun(enable: value),
                        );
                  } else {
                    ref.read(vpnSettingProvider.notifier).updateState(
                          (state) => state.copyWith(systemProxy: value),
                        );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckUpdateTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CheckUpdateTile> createState() => _CheckUpdateTileState();
}

class _CheckUpdateTileState extends ConsumerState<_CheckUpdateTile> {
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
      if (mounted) XBoardNotification.showError('检查更新失败: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _checkForUpdates,
        hoverColor: colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.03),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(colorScheme.tertiary, Colors.white,
                          isDark ? 0.15 : 0.25)!,
                      colorScheme.tertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.tertiary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '检查更新',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentVersion.isNotEmpty
                          ? '当前版本 v$_currentVersion'
                          : '正在获取版本...',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              _isChecking
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
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      size: 20,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════╗
// ║  辅助函数                                                    ║
// ╚══════════════════════════════════════════════════════════════╝

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// SDK UserModel → DomainUser
DomainUser _mapUserModel(UserModel user) {
  return DomainUser(
    email: user.email,
    uuid: user.uuid,
    avatarUrl: user.avatarUrl,
    planId: user.planId,
    transferLimit: user.transferEnable.toInt(),
    uploadedBytes: 0,
    downloadedBytes: 0,
    balanceInCents: user.balance.toInt(),
    commissionBalanceInCents: user.commissionBalance.toInt(),
    expiredAt: user.expiredAt,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
    banned: user.banned,
    remindExpire: user.remindExpire,
    remindTraffic: user.remindTraffic,
    discount: user.discount,
    commissionRate: user.commissionRate,
    telegramId: user.telegramId,
  );
}

/// SDK SubscriptionModel → DomainSubscription
DomainSubscription _mapSubscriptionModel(SubscriptionModel sub) {
  return DomainSubscription(
    subscribeUrl: sub.subscribeUrl ?? '',
    email: sub.email ?? '',
    uuid: sub.uuid ?? '',
    planId: sub.planId ?? 0,
    planName: sub.planName,
    token: sub.token,
    transferLimit: sub.transferEnable ?? 0,
    uploadedBytes: sub.u ?? 0,
    downloadedBytes: sub.d ?? 0,
    speedLimit: sub.speedLimit,
    deviceLimit: sub.deviceLimit,
    expiredAt: sub.expiredAt,
    nextResetAt: sub.nextResetAt,
  );
}
