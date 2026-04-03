import 'dart:math' as math;
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/auth/dialogs/login_dialog.dart';
import 'package:fl_clash/xboard/domain/models/subscription.dart';

/// 大型圆形电源按钮 — 高级拟物 + 玻璃质感
class PowerConnectButton extends ConsumerStatefulWidget {
  const PowerConnectButton({super.key});

  @override
  ConsumerState<PowerConnectButton> createState() => _PowerConnectButtonState();
}

class _PowerConnectButtonState extends ConsumerState<PowerConnectButton>
    with TickerProviderStateMixin {
  // 连接态呼吸脉冲
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  // 点击缩放
  late AnimationController _toggleController;
  late Animation<double> _scaleAnimation;
  // 连接态光环旋转
  late AnimationController _ringController;
  // 悬停
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  // 断开态呼吸微光
  late AnimationController _idleController;
  late Animation<double> _idleAnimation;

  bool _isStart = false;

  @override
  void initState() {
    super.initState();
    _isStart = globalState.appState.runTime != null;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _toggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _toggleController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    );

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _idleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    if (_isStart) {
      _pulseController.repeat(reverse: true);
      _ringController.repeat();
    } else {
      _idleController.repeat(reverse: true);
    }

    ref.listenManual(
      runTimeProvider.select((state) => state != null),
      (prev, next) {
        if (next != _isStart) {
          _isStart = next;
          if (_isStart) {
            _idleController.stop();
            _pulseController.repeat(reverse: true);
            _ringController.repeat();
          } else {
            _pulseController.stop();
            _pulseController.reset();
            _ringController.stop();
            _ringController.reset();
            _idleController.repeat(reverse: true);
          }
          if (mounted) setState(() {});
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _toggleController.dispose();
    _ringController.dispose();
    _hoverController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 连接前检查（断开连接不检查）
    if (!_isStart) {
      // 游客模式：未登录先提示登录
      final isAuthenticated = ref.read(xboardUserProvider).isAuthenticated;
      if (!isAuthenticated) {
        _showGuestLoginDialog();
        return;
      }

      // 检查是否为演示模式（未购买套餐）
      final isDemoMode = ref.read(isDemoModeProvider);
      if (isDemoMode) {
        _showNoSubscriptionDialog();
        return;
      }

      // 检查是否有订阅（有 profile 说明有订阅）
      final hasProfile = ref.read(startButtonSelectorStateProvider).hasProfile;
      if (!hasProfile) {
        _showNoSubscriptionDialog();
        return;
      }

      // 检查节点列表是否为空
      final groups = ref.read(groupsProvider);
      if (groups.isEmpty) {
        _showNoNodesDialog();
        return;
      }

      final subscription = ref.read(subscriptionInfoProvider);
      final userInfo = ref.read(userInfoProvider);
      final expiredAt = subscription?.expiredAt ?? userInfo?.expiredAt;

      if (expiredAt != null && expiredAt.isBefore(DateTime.now())) {
        _showExpiredDialog();
        return;
      }

      // 检查流量是否用尽
      if (subscription != null && subscription.transferLimit > 0) {
        final usageRatio = subscription.totalUsedBytes / subscription.transferLimit;
        if (usageRatio >= 1.0) {
          _showTrafficExhaustedDialog();
          return;
        }
        if (usageRatio >= 0.95) {
          _showTrafficWarningDialog(usageRatio);
          // 流量快用尽只提醒，不拦截连接，继续执行下方逻辑
        }
      }
    }

    _toggleController.forward().then((_) {
      _toggleController.reverse();
    });
    _isStart = !_isStart;
    // ── 关键: 在这里直接启停动画控制器! ──
    if (_isStart) {
      _idleController.stop();
      _idleController.reset();
      _pulseController.repeat(reverse: true);
      _ringController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.reset();
      _ringController.stop();
      _ringController.reset();
      _idleController.repeat(reverse: true);
    }
    setState(() {});
    debouncer.call(
      FunctionTag.updateStatus,
      () {
        globalState.appController.updateStatus(_isStart);
      },
      duration: commonDuration,
    );
  }

  /// 游客模式提示：登录后使用更多功能
  void _showGuestLoginDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.login_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
        ),
        title: const Text(
          '登录后使用更多功能',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          '登录账号并购买套餐后\n即可连接使用代理服务',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      LoginDialog.show(context);
                    },
                    child: const Text('登录账号'),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      '稍后再说',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.schedule, color: Colors.red.shade600, size: 32),
        ),
        title: const Text(
          '订阅已过期',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          '您的订阅已过期，无法使用代理服务。\n请续费套餐以继续使用。',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      '稍后处理',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.go('/plans');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('去续费'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTrafficExhaustedDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.data_usage, color: Colors.red.shade600, size: 32),
        ),
        title: const Text(
          '流量已用完',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          '您的套餐流量已全部用完，无法继续使用代理服务。\n请续费或购买更高等级套餐。',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      '稍后处理',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.go('/plans');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('购买套餐'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTrafficWarningDialog(double usageRatio) {
    final percent = (usageRatio * 100).toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.data_usage, color: Colors.orange.shade700, size: 32),
        ),
        title: const Text(
          '流量即将用尽',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '您的套餐流量已使用 $percent%，即将用完。\n建议及时续费或升级套餐。',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      '继续使用',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.go('/plans');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('升级套餐'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNoSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shopping_cart_outlined, color: Colors.orange, size: 32),
        ),
        title: const Text(
          '暂无订阅',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          '您当前没有订阅套餐，无法连接。\n请先购买套餐后再使用。',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      // 未登录先弹登录，已登录去购买
                      final isAuthenticated = ref.read(xboardUserProvider).isAuthenticated;
                      if (!isAuthenticated) {
                        LoginDialog.show(context);
                      } else {
                        context.go('/plans');
                      }
                    },
                    child: const Text('购买套餐'),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      '稍后再说',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNoNodesDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.cloud_off, color: Colors.red, size: 32),
        ),
        title: const Text(
          '节点未加载',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          '当前没有可用节点，无法连接。\n请尝试以下操作：\n\n1. 点击「⟳刷新订阅」更新节点\n2. 退出账号并重启客户端\n3. 以上方法无效请联系客服',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      '我知道了',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    if (!state.isInit) {
      return _buildLoading(context);
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = cs.primary;

    // ── 响应式尺寸 ──
    final s = (MediaQuery.sizeOf(context).shortestSide / 400).clamp(0.6, 1.0);
    final double btnR = 58 * s;
    final double trackR = 74 * s;
    final double outerR = 82 * s;
    final double canvas = 236 * s;
    final double iconSz = 40 * s;

    // ── 连接态: 主题色偏亮 (饱和度更高、明度上提) ──
    final onBright =
        Color.lerp(primary, Colors.white, isDark ? 0.35 : 0.25)!;
    final onDark = Color.lerp(primary, Colors.black, isDark ? 0.05 : 0.05)!;
    // 弧光色: 比按钮再亮一档, 在底盘上要醒目
    final arcColor =
        Color.lerp(primary, Colors.white, isDark ? 0.45 : 0.10)!;

    // ── 未连接态: 主题色略淡 ──
    final offBright =
        Color.lerp(primary, Colors.white, isDark ? 0.25 : 0.18)!;
    final offDark =
        Color.lerp(primary, Colors.black, isDark ? 0.12 : 0.08)!;

    // ── 底盘 ──
    final basePlate = isDark ? const Color(0xFF14141C) : cs.surface;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseAnimation,
            _scaleAnimation,
            _hoverAnimation,
            _idleAnimation,
          ]),
          builder: (context, _) {
            final pulse = _isStart ? _pulseAnimation.value : 0.0;
            final idle = !_isStart ? _idleAnimation.value : 0.0;
            final scale = _scaleAnimation.value;
            final hover = _hoverAnimation.value;

            final stateColor = primary;

            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: canvas,
                height: canvas,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // ═══════ L0: 脉冲光晕 ═══════
                    Container(
                      width: outerR * 2 + 16 +
                          (_isStart ? 36 * pulse : 10 * idle),
                      height: outerR * 2 + 16 +
                          (_isStart ? 36 * pulse : 10 * idle),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: stateColor.withValues(
                                alpha: _isStart
                                    ? (isDark ? 0.22 : 0.16) *
                                        (1 - pulse * 0.3)
                                    : (isDark ? 0.06 : 0.05) +
                                        idle * 0.04 +
                                        hover * 0.05),
                            blurRadius: _isStart
                                ? 44 + 32 * pulse
                                : 24 + idle * 8 + hover * 10,
                            spreadRadius: _isStart
                                ? 6 + 18 * pulse
                                : 2 + idle * 2,
                          ),
                        ],
                      ),
                    ),

                    // ═══════ L1: 连接态涟漪 (独立监听ringController) ═══════
                    if (_isStart)
                      AnimatedBuilder(
                        animation: _ringController,
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: _buildRipples(
                              _ringController.value, arcColor, outerR * 2, 44 * s,
                            ),
                          );
                        },
                      ),

                    // ═══════ L2: 最外层装饰环 ═══════
                    Container(
                      width: outerR * 2,
                      height: outerR * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isStart
                              ? arcColor.withValues(
                                  alpha: isDark ? 0.25 : 0.30)
                              : primary.withValues(
                                  alpha: (isDark ? 0.16 : 0.12) +
                                      idle * 0.04 +
                                      hover * 0.06),
                          width: 1.5 * s,
                        ),
                      ),
                    ),

                    // ═══════ L3: 底盘 ═══════
                    Container(
                      width: outerR * 2 - 3,
                      height: outerR * 2 - 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: basePlate,
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: stateColor.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  spreadRadius: -2,
                                ),
                              ],
                      ),
                    ),

                    // ═══════ L4: 弧光轨道底色 ═══════
                    Container(
                      width: trackR * 2 + 6 * s,
                      height: trackR * 2 + 6 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isStart
                              ? arcColor.withValues(
                                  alpha: isDark ? 0.14 : 0.12)
                              : primary.withValues(
                                  alpha: (isDark ? 0.10 : 0.08) +
                                      idle * 0.03),
                          width: 3.5 * s,
                        ),
                      ),
                    ),

                    // ═══════ L5: 四弧追逐 ═══════
                    if (_isStart)
                      RepaintBoundary(
                        child: SizedBox(
                          width: trackR * 2 + 12 * s,
                          height: trackR * 2 + 12 * s,
                          child: CustomPaint(
                            painter: _ChaseArcPainter(
                              ringCtrl: _ringController,
                              color: arcColor,
                              outerStroke: 3.2 * s,
                              innerStroke: 2.0 * s,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),

                    // ═══════ L6: 内环装饰线 ═══════
                    Container(
                      width: btnR * 2 + 8 * s,
                      height: btnR * 2 + 8 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isStart
                              ? arcColor.withValues(
                                  alpha: isDark ? 0.20 : 0.24)
                              : primary.withValues(
                                  alpha: (isDark ? 0.14 : 0.10) +
                                      idle * 0.03 +
                                      hover * 0.05),
                          width: 1.2 * s,
                        ),
                      ),
                    ),

                    // ═══════ L7: 主按钮 ═══════
                    Container(
                      width: btnR * 2,
                      height: btnR * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: const Alignment(-0.3, -0.9),
                          end: const Alignment(0.3, 1.0),
                          colors: _isStart
                              ? [onBright, onDark]
                              : [offBright, offDark],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(
                              alpha: isDark ? 0.16 : 0.30),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(
                                alpha: _isStart
                                    ? (isDark ? 0.38 : 0.30) +
                                        pulse * 0.08
                                    : (isDark ? 0.24 : 0.18) +
                                        idle * 0.04),
                            blurRadius: _isStart
                                ? 20 + 8 * pulse
                                : 16 + idle * 3,
                            spreadRadius: _isStart
                                ? 2 + 4 * pulse
                                : 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: isDark ? 0.30 : 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                          if (!isDark)
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.60),
                              blurRadius: 6,
                              offset: const Offset(0, -2),
                            ),
                        ],
                      ),
                      child: _isStart
                          ? _buildTimerContent(iconSz)
                          : Center(
                              child: Icon(
                                Icons.power_settings_new_rounded,
                                size: iconSz,
                                color: Colors.white.withValues(
                                    alpha: 0.88 + idle * 0.08),
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(
                                        alpha: 0.35 + idle * 0.12),
                                    blurRadius: 10 + idle * 4,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 连接态: 白色图标 + 计时 ──
  Widget _buildTimerContent(double iconSz) {
    return Consumer(
      builder: (_, ref, __) {
        final runTime = ref.watch(runTimeProvider);
        final text = utils.getTimeText(runTime);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              size: iconSz * 0.58,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.60),
                  blurRadius: 14,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: iconSz * 0.25,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── 加载态 ──
  Widget _buildLoading(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = (MediaQuery.sizeOf(context).shortestSide / 400).clamp(0.6, 1.0);
    final double btnR = 60 * s;
    final double ringR = 78 * s;
    final double canvas = 230 * s;
    final c = cs.onSurface.withValues(alpha: 0.10);

    return SizedBox(
      width: canvas,
      height: canvas,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: ringR * 2,
            height: ringR * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c, width: 2.5),
            ),
          ),
          Container(
            width: btnR * 2,
            height: btnR * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.onSurface.withValues(alpha: 0.03),
              border: Border.all(color: c, width: 1),
            ),
            child: Center(
              child: SizedBox(
                width: 26 * s,
                height: 26 * s,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.primary.withValues(alpha: 0.40),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 涟漪环 ──
  List<Widget> _buildRipples(
      double phase, Color color, double center, double expand) {
    return List.generate(3, (i) {
      final p = (phase + i / 3) % 1.0;
      final a = math.sin(p * math.pi) * 0.28;
      final sz = center + p * expand * 2;
      if (a < 0.01) return const SizedBox.shrink();
      return Container(
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: a * 0.65),
            width: 1.2 * (1 - p * 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: a * 0.18),
              blurRadius: 8 + p * 6,
            ),
          ],
        ),
      );
    });
  }
}

// ────────────────────────────────────────────────────
// 三弧旋转 — 渐变尾巴 + 纯匀速旋转, 无弧长呼吸
// 外圈: 2条同向不同相位 (speed 1)
// 内圈: 1条反向 (speed -1)
// ────────────────────────────────────────────────────
class _ChaseArcPainter extends CustomPainter {
  final AnimationController ringCtrl;
  final Color color;
  final double outerStroke;
  final double innerStroke;
  final bool isDark;

  _ChaseArcPainter({
    required this.ringCtrl,
    required this.color,
    required this.outerStroke,
    required this.innerStroke,
    required this.isDark,
  }) : super(repaint: ringCtrl);

  static const _twoPi = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final t = ringCtrl.value; // 0..1 纯线性旋转
    final center = Offset(size.width / 2, size.height / 2);

    final outerR = (size.width - outerStroke) / 2 - 4;
    final innerR = outerR - outerStroke - innerStroke - 4;

    final headAlpha = isDark ? 0.92 : 0.97;

    // 4 弧: 固定弧长, 纯匀速, 外圈顺时针, 内圈反向
    final arcs = <_ArcDef>[
      // 外弧1: 较长 ~130°
      _ArcDef(outerR, outerStroke, 1, 0.00, 0.72, headAlpha),
      // 外弧2: 较短 ~95°, 对侧
      _ArcDef(outerR, outerStroke, 1, 0.55, 0.53, headAlpha * 0.80),
      // 内弧1: 反向 ~110°
      _ArcDef(innerR, innerStroke, -1, 0.10, 0.61, headAlpha * 0.85),
      // 内弧2: 反向 ~85°, 对侧
      _ArcDef(innerR, innerStroke, -1, 0.62, 0.47, headAlpha * 0.70),
    ];

    for (final a in arcs) {
      final baseAngle = (t * a.speed + a.phase) * _twoPi;
      final sweep = math.pi * a.sweepFrac;
      final rect = Rect.fromCircle(center: center, radius: a.radius);

      // 反向弧: 翻转绘制方向, 渐变头部始终朝运动方向
      final bool reversed = a.speed < 0;
      final drawAngle = reversed ? baseAngle + sweep : baseAngle;
      final drawSweep = reversed ? -sweep : sweep;

      // 渐变: 尾巴透明 → 头部实色 (始终沿运动方向)
      final gradientColors = reversed
          ? [
              color.withValues(alpha: a.alpha),
              color.withValues(alpha: a.alpha * 0.25),
              color.withValues(alpha: 0.0),
            ]
          : [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: a.alpha * 0.25),
              color.withValues(alpha: a.alpha),
            ];
      final gradientStops = reversed
          ? const [0.0, 0.60, 1.0]
          : const [0.0, 0.40, 1.0];

      final shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: gradientColors,
        stops: gradientStops,
        transform: GradientRotation(baseAngle),
      ).createShader(rect);

      // 柔光底
      canvas.drawArc(
        rect, drawAngle, drawSweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = a.stroke + 3
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: isDark ? 0.08 : 0.06),
      );

      // 主弧 (渐变着色)
      canvas.drawArc(
        rect, drawAngle, drawSweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = a.stroke
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }
  }

  @override
  bool shouldRepaint(_ChaseArcPainter old) => false;
}

class _ArcDef {
  final double radius;
  final double stroke;
  final int speed;        // 整圈数/周期 (正=顺时针, 负=逆时针)
  final double phase;     // 起始相位 0..1
  final double sweepFrac; // 弧长占π的比例 (固定值)
  final double alpha;
  const _ArcDef(this.radius, this.stroke, this.speed, this.phase, this.sweepFrac, this.alpha);
}
