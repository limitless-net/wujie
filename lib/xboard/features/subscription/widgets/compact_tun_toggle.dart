import 'dart:io';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 紧凑 TUN 模式切换 — 小圆形图标按钮
class CompactTunToggle extends ConsumerWidget {
  const CompactTunToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    final tunEnabled = isDesktop
        ? ref.watch(patchClashConfigProvider.select((s) => s.tun.enable))
        : ref.watch(vpnSettingProvider.select((s) => s.systemProxy));

    return GestureDetector(
      onTap: () {
        if (isDesktop) {
          ref.read(patchClashConfigProvider.notifier).updateState(
            (state) => state.copyWith.tun(enable: !tunEnabled),
          );
        } else {
          ref.read(vpnSettingProvider.notifier).updateState(
            (state) => state.copyWith(systemProxy: !tunEnabled),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tunEnabled
              ? colorScheme.primary.withValues(alpha: 0.15)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
          shape: BoxShape.circle,
          border: Border.all(
            color: tunEnabled
                ? colorScheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            'T',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tunEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.35),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
