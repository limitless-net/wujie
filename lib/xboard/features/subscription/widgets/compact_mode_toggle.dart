import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('compact_mode_toggle.dart');

/// 紧凑模式切换 — 药丸形状的智能/全局切换
class CompactModeToggle extends ConsumerWidget {
  const CompactModeToggle({super.key});

  void _handleModeChange(WidgetRef ref, Mode modeOption) {
    _logger.debug('[CompactModeToggle] 切换模式到: $modeOption');
    globalState.appController.changeMode(modeOption);
    if (modeOption == Mode.global) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _selectValidProxyForGlobalMode(ref);
      });
    }
  }

  void _selectValidProxyForGlobalMode(WidgetRef ref) {
    final groups = ref.read(groupsProvider);
    if (groups.isEmpty) return;

    final globalGroup = groups.firstWhere(
      (group) => group.name == GroupName.GLOBAL.name,
      orElse: () => groups.first,
    );

    if (globalGroup.all.isEmpty) return;

    Proxy? validProxy;
    for (final proxy in globalGroup.all) {
      if (proxy.name.toUpperCase() != 'DIRECT' &&
          proxy.name.toUpperCase() != 'REJECT') {
        validProxy = proxy;
        break;
      }
    }

    if (validProxy != null) {
      globalState.appController.updateCurrentSelectedMap(
        globalGroup.name,
        validProxy.name,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    final isRule = mode == Mode.rule;
    final ruleLabel = Intl.message(Mode.rule.name);
    final globalLabel = Intl.message(Mode.global.name);

    final baseStyle = textTheme.bodyMedium?.copyWith(fontSize: 14) ??
        const TextStyle(fontSize: 14);
    const pillPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 8);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Stack(
        children: [
          // ── 1. 隐形占位行（定义 Stack 尺寸）──
          Opacity(
            opacity: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: pillPadding,
                  child: Text(ruleLabel, style: baseStyle),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: pillPadding,
                  child: Text(globalLabel, style: baseStyle),
                ),
              ],
            ),
          ),
          // ── 2. 滑动渐变指示器 ──
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment:
                  isRule ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-0.3, -0.9),
                      end: const Alignment(0.3, 1.0),
                      colors: [
                        Color.lerp(colorScheme.primary, Colors.white,
                            isDark ? 0.25 : 0.22)!,
                        Color.lerp(colorScheme.primary, Colors.black,
                            isDark ? 0.03 : 0.03)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: isDark ? 0.16 : 0.30),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary
                            .withValues(alpha: isDark ? 0.35 : 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.20 : 0.10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── 3. 文字标签层（可交互）──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _handleModeChange(ref, Mode.rule),
                child: Padding(
                  padding: pillPadding,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: baseStyle.copyWith(
                      color: isRule
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface
                              .withValues(alpha: 0.6),
                      fontWeight:
                          isRule ? FontWeight.w600 : FontWeight.w400,
                    ),
                    child: Text(ruleLabel),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _handleModeChange(ref, Mode.global),
                child: Padding(
                  padding: pillPadding,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: baseStyle.copyWith(
                      color: !isRule
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface
                              .withValues(alpha: 0.6),
                      fontWeight:
                          !isRule ? FontWeight.w600 : FontWeight.w400,
                    ),
                    child: Text(globalLabel),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
