import 'dart:async';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------
// Flag images: put flags at  assets/images/flags/<code>.png
//   e.g.  hk.png  us.png  jp.png  kr.png  sg.png  gb.png ...
// If the file is missing the widget falls back to a colored badge.
// ---------------------------------------------------------------

const _regionCodeMap = <String, String>{
  // Chinese
  '香港': 'hk', '台湾': 'tw', '日本': 'jp', '美国': 'us',
  '韩国': 'kr', '新加坡': 'sg', '德国': 'de', '英国': 'gb',
  '法国': 'fr', '加拿大': 'ca', '澳大利亚': 'au', '印度': 'in',
  '俄罗斯': 'ru', '巴西': 'br', '荷兰': 'nl', '土耳其': 'tr',
  '泰国': 'th', '越南': 'vn', '菲律宾': 'ph', '马来西亚': 'my',
  '印尼': 'id', '阿根廷': 'ar', '意大利': 'it', '西班牙': 'es',
  '瑞士': 'ch', '波兰': 'pl', '墨西哥': 'mx', '南非': 'za',
  '乌克兰': 'ua', '阿联酋': 'ae', '埃及': 'eg', '以色列': 'il',
  '爱尔兰': 'ie', '智利': 'cl', '柬埔寨': 'kh', '缅甸': 'mm',
  // English
  'Hong Kong': 'hk', 'HongKong': 'hk', 'Hongkong': 'hk',
  'Taiwan': 'tw',
  'Japan': 'jp',
  'USA': 'us', 'United States': 'us', 'America': 'us',
  'Korea': 'kr', 'South Korea': 'kr',
  'Singapore': 'sg',
  'Germany': 'de',
  'United Kingdom': 'gb', 'Britain': 'gb', 'UK': 'gb',
  'France': 'fr',
  'Canada': 'ca',
  'Australia': 'au',
  'India': 'in',
  'Russia': 'ru',
  'Brazil': 'br',
  'Netherlands': 'nl',
  'Turkey': 'tr',
  'Thailand': 'th',
  'Vietnam': 'vn',
  'Philippines': 'ph',
  'Malaysia': 'my',
  'Indonesia': 'id',
  'Argentina': 'ar',
  'Italy': 'it',
  'Spain': 'es',
  'Switzerland': 'ch',
  'Poland': 'pl',
  'Mexico': 'mx',
  'South Africa': 'za',
  'Ukraine': 'ua',
  'UAE': 'ae',
  'Egypt': 'eg',
  'Israel': 'il',
  'Ireland': 'ie',
  'Chile': 'cl',
  'Cambodia': 'kh',
  'Myanmar': 'mm',
};

const _fallbackColors = <String, Color>{
  'hk': Color(0xFFE53935), 'tw': Color(0xFF1565C0), 'jp': Color(0xFFD32F2F),
  'us': Color(0xFF1565C0), 'kr': Color(0xFF0D47A1), 'sg': Color(0xFFE53935),
  'de': Color(0xFF424242), 'gb': Color(0xFF0D47A1), 'fr': Color(0xFF1565C0),
  'ca': Color(0xFFD32F2F), 'au': Color(0xFF1565C0), 'in': Color(0xFFFF8F00),
  'ru': Color(0xFF1565C0), 'br': Color(0xFF2E7D32), 'nl': Color(0xFFFF6F00),
  'tr': Color(0xFFD32F2F), 'th': Color(0xFF0D47A1), 'vn': Color(0xFFD32F2F),
  'my': Color(0xFF0D47A1), 'id': Color(0xFFD32F2F), 'ph': Color(0xFF1565C0),
  'it': Color(0xFF2E7D32), 'es': Color(0xFFD32F2F), 'ch': Color(0xFFD32F2F),
  'mx': Color(0xFF2E7D32), 'ua': Color(0xFF1565C0), 'ae': Color(0xFF2E7D32),
  'kh': Color(0xFF1565C0), 'cl': Color(0xFF1565C0),
};

String _getRegionCode(String name) {
  for (final entry in _regionCodeMap.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return '';
}

/// Hide DIRECT, REJECT, info-only nodes, and group references.
/// [groupNames] is the set of all proxy group names — proxies whose name
/// matches a group are sub-group references (e.g. "无界", "自动选择", "故障转移").
bool _isDisplayableNode(Proxy proxy, [Set<String>? groupNames]) {
  final n = proxy.name;
  if (n == 'DIRECT' || n == 'REJECT') return false;
  // Filter info-only entries: contain traffic/expiry keywords
  if (n.contains('剩余流量') || n.contains('套餐到期') ||
      n.contains('过期时间') || n.contains('到期时间') ||
      n.contains('重置') || n.contains('入站') ||
      n.contains('Remaining') || n.contains('Expire') || n.contains('Reset')) {
    return false;
  }
  // Filter purchase/subscription links
  if (n.contains('购买') || n.contains('官网') || n.contains('https://')) {
    return false;
  }
  // Filter group references (sub-groups like "无界", "自动选择", "故障转移")
  if (groupNames != null && groupNames.contains(n)) return false;
  return true;
}

// ---------------------------------------------------------------
// Resolve current proxy group and selected node
// [parentGroup] is the top-level Selector group (if current is a sub-group)
// ---------------------------------------------------------------
({Group? group, Group? parentGroup, Proxy? proxy, String selectedName})
    _resolveCurrentNode(
        List<Group> groups, Map<String, String> selectedMap, Mode mode) {
  if (groups.isEmpty) {
    return (group: null, parentGroup: null, proxy: null, selectedName: '');
  }

  Group? currentGroup;
  Group? parentGroup; // Track the parent Selector if we dive into a sub-group
  if (mode == Mode.global) {
    currentGroup = groups.firstWhere(
      (g) => g.name == GroupName.GLOBAL.name,
      orElse: () => groups.first,
    );
  } else {
    for (final group in groups) {
      if (group.hidden == true) continue;
      if (group.name == GroupName.GLOBAL.name) continue;
      final sel = selectedMap[group.name];
      if (sel != null && sel.isNotEmpty) {
        final refGroup =
            groups.firstWhere((g) => g.name == sel, orElse: () => group);
        if (refGroup.name == sel && refGroup.type == GroupType.URLTest) {
          parentGroup = group; // "无界" Selector is the parent
          currentGroup = refGroup; // "自动选择" URLTest is the display group
        } else {
          currentGroup = group;
        }
        break;
      }
    }
    if (currentGroup == null) {
      currentGroup = groups.firstWhere(
        (g) => g.hidden != true && g.name != GroupName.GLOBAL.name,
        orElse: () => groups.first,
      );
      final nowValue = currentGroup.now;
      if (nowValue != null && nowValue.isNotEmpty) {
        final refG = groups.firstWhere(
          (g) => g.name == nowValue,
          orElse: () => currentGroup!,
        );
        if (refG.name == nowValue && refG.type == GroupType.URLTest) {
          parentGroup = currentGroup;
          currentGroup = refG;
        }
      }
    }
  }

  if (currentGroup.all.isEmpty) {
    return (
      group: null,
      parentGroup: null,
      proxy: null,
      selectedName: ''
    );
  }

  // Build set of group names for filtering
  final groupNames = groups.map((g) => g.name).toSet();

  final selName = selectedMap[currentGroup.name] ?? '';
  final realName = currentGroup.type == GroupType.URLTest
      ? (currentGroup.now ?? '')
      : currentGroup.getCurrentSelectedName(selName);

  late Proxy currentProxy;
  if (realName.isNotEmpty) {
    currentProxy = currentGroup.all.firstWhere(
      (p) => p.name == realName,
      orElse: () => currentGroup!.all.first,
    );
  } else {
    currentProxy = currentGroup.all.first;
  }

  // If the resolved proxy is an info/group node, pick the first displayable one
  if (!_isDisplayableNode(currentProxy, groupNames)) {
    final displayable = currentGroup.all
        .where((p) => _isDisplayableNode(p, groupNames))
        .toList();
    if (displayable.isEmpty) {
      return (
        group: currentGroup,
        parentGroup: parentGroup,
        proxy: null,
        selectedName: ''
      );
    }
    currentProxy = displayable.first;
  }

  return (
    group: currentGroup,
    parentGroup: parentGroup,
    proxy: currentProxy,
    selectedName: realName
  );
}

// ---------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------
class CompactNodeSelector extends ConsumerStatefulWidget {
  const CompactNodeSelector({super.key});

  @override
  ConsumerState<CompactNodeSelector> createState() =>
      _CompactNodeSelectorState();
}

class _CompactNodeSelectorState extends ConsumerState<CompactNodeSelector> {
  final _link = LayerLink();
  final _pillKey = GlobalKey();
  final _overlayController = OverlayPortalController();
  bool _isTesting = false;
  bool _isRefreshing = false;
  Timer? _autoTestTimer;

  // Track group structure to only auto-test on real config changes
  String _lastGroupSignature = '';

  // Pill position captured at toggle time for panel height calculation
  double _pillTop = 500;

  @override
  void dispose() {
    _autoTestTimer?.cancel();
    super.dispose();
  }

  /// Build a signature from group names + node counts to detect real changes
  String _groupSignature(List<Group> groups) {
    final buf = StringBuffer();
    for (final g in groups) {
      buf.write('${g.name}:${g.all.length};');
    }
    return buf.toString();
  }

  /// Auto-test only when group structure actually changed (subscription import / core restart)
  void _maybeAutoTest(List<Group> prev, List<Group> next) {
    final sig = _groupSignature(next);
    if (sig == _lastGroupSignature) return; // same structure, skip
    _lastGroupSignature = sig;
    if (next.isEmpty || _isTesting || _isRefreshing) return;

    _autoTestTimer?.cancel();
    _autoTestTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _isTesting || _isRefreshing) return;
      final groups = ref.read(groupsProvider);
      final selectedMap = ref.read(selectedMapProvider);
      final mode = ref.read(patchClashConfigProvider).mode;
      final resolved = _resolveCurrentNode(groups, selectedMap, mode);
      if (resolved.group != null) {
        debugPrint('[CompactNodeSelector] 自动触发延迟测试 (config changed)');
        _testDelay(resolved.group!);
      }
    });
  }

  void _toggle() {
    // Capture pill Y so we know how much space is available above it
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      _pillTop = box.localToGlobal(Offset.zero).dy;
    }
    if (_overlayController.isShowing) {
      _overlayController.hide();
    } else {
      _overlayController.show();
    }
    setState(() {});
  }

  void _close() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final mode = ref.watch(patchClashConfigProvider.select((s) => s.mode));

    // Auto-test delays only when group structure changes (subscription import / core restart)
    ref.listen(groupsProvider, (previous, next) {
      _maybeAutoTest(previous ?? [], next);
    });

    final resolved = _resolveCurrentNode(groups, selectedMap, mode);
    final currentGroup = resolved.group;
    final currentProxy = resolved.proxy;
    final realSelected = resolved.selectedName;

    // Available height above pill minus toolbar (~52) minus gap (8) minus top padding
    final safeTop = MediaQuery.of(context).padding.top + 8;
    final maxListH = (_pillTop - 8 - 52 - safeTop).clamp(80.0, 320.0);

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (ctx) => Stack(
        children: [
          // Background: tap OUTSIDE panel → close
          // Using opaque so it blocks all pointer events in empty area
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          // Panel: wrap with opaque GestureDetector to ABSORB taps
          // so the background layer never sees taps inside the panel.
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -6),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // absorb tap — stops it reaching background
                child: _NodePanel(
                  group: currentGroup,
                  allGroups: groups,
                  realSelected: realSelected,
                  isTesting: _isTesting,
                  isRefreshing: _isRefreshing,
                  maxListHeight: maxListH,
                  onSelectNode: (proxy) {
                    if (currentGroup != null) {
                      _selectNode(
                        currentGroup.name,
                        currentGroup.type,
                        proxy,
                        parentGroup: resolved.parentGroup,
                      );
                    }
                    _close();
                  },
                  onDelayTest: _testSingleDelay,
                  onTest: () {
                    if (currentGroup != null) _testDelay(currentGroup);
                  },
                  onRefresh: _refreshSub,
                ),
              ),
            ),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: _buildPill(context, currentProxy),
      ),
    );
  }

  Widget _buildPill(BuildContext context, Proxy? proxy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final isOpen = _overlayController.isShowing;

    if (proxy == null) return _EmptyPill(key: _pillKey, onTap: _toggle);

    final delay = ref.watch(getDelayProvider(
      proxyName: proxy.name,
      testUrl: ref.read(appSettingProvider).testUrl,
    ));

    return GestureDetector(
      key: _pillKey,
      onTap: _toggle,
      onLongPress: () => autoLatencyService.testProxy(proxy, forceTest: true),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: isOpen ? 0.14 : 0.08)
              : (isOpen
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOpen
                ? colorScheme.primary.withValues(alpha: 0.4)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : colorScheme.primary.withValues(alpha: 0.10)),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FlagWidget(name: proxy.name, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                proxy.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _DelayText(delay: delay),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectNode(
    String groupName,
    GroupType groupType,
    Proxy proxy, {
    Group? parentGroup,
  }) {
    // When the display group is a URLTest sub-group of a Selector parent,
    // update the parent Selector to point directly to the proxy node.
    // This overrides the URLTest auto-selection and gives the user full
    // manual control.
    if (parentGroup != null && parentGroup.type == GroupType.Selector) {
      debugPrint(
          '[CompactNodeSelector] 手动选节点: parent=${parentGroup.name} -> ${proxy.name}');
      globalState.appController
          .updateCurrentSelectedMap(parentGroup.name, proxy.name);
      globalState.appController
          .changeProxyDebounce(parentGroup.name, proxy.name);
      return;
    }

    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final cur = ref.read(getProxyNameProvider(groupName));
      final next = isComputedSelected
          ? (cur == proxy.name ? '' : proxy.name)
          : proxy.name;
      globalState.appController.updateCurrentSelectedMap(groupName, next);
      globalState.appController.changeProxyDebounce(groupName, next);
    }
  }

  void _refreshSub() async {
    if (_isRefreshing) return;
    final wasRunning = ref.read(runTimeProvider) != null;
    setState(() => _isRefreshing = true);
    try {
      // If no nodes at all, the domain might be blocked — re-race first
      final groups = ref.read(groupsProvider);
      if (groups.isEmpty) {
        XBoardNotification.showInfo('正在重新检测域名...');
        try {
          await ref.read(initializationProvider.notifier).refresh();
        } catch (_) {}
      }
      XBoardNotification.showInfo('正在刷新订阅...');
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
      // Auto-test all nodes after successful refresh
      if (mounted) {
        // Wait a moment for groups to update from subscription import
        await Future.delayed(const Duration(seconds: 3));
        final updatedGroups = ref.read(groupsProvider);
        final mode = ref.read(patchClashConfigProvider).mode;
        final selectedMap = ref.read(selectedMapProvider);
        final resolved = _resolveCurrentNode(updatedGroups, selectedMap, mode);
        if (resolved.group != null && resolved.group!.all.isNotEmpty) {
          await _testDelayAsync(resolved.group!);
        }
      }
      // All operations done, show final notification
      if (mounted) {
        if (wasRunning) {
          XBoardNotification.showSuccess(
            '订阅已更新，代理连接已断开，请重新连接',
            duration: const Duration(seconds: 5),
          );
        } else {
          XBoardNotification.showSuccess('订阅已刷新');
        }
      }
    } catch (e) {
      if (mounted) XBoardNotification.showError('刷新失败: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _testDelay(Group group) async {
    await _testDelayAsync(group);
  }

  Future<void> _testDelayAsync(Group group) async {
    if (_isTesting) return;
    setState(() => _isTesting = true);
    try {
      final testUrl = ref.read(appSettingProvider).testUrl;
      debugPrint('[CompactNodeSelector] 批量测试: ${group.all.length} 个节点, testUrl=$testUrl');
      await delayTest(group.all, testUrl);
      debugPrint('[CompactNodeSelector] 批量测试完成');
    } catch (e) {
      debugPrint('[CompactNodeSelector] 批量测试失败: $e');
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _testSingleDelay(Proxy proxy) async {
    try {
      final testUrl = ref.read(appSettingProvider).testUrl;
      final appController = globalState.appController;
      final state = appController.getProxyCardState(proxy.name);
      debugPrint('[CompactNodeSelector] 单节点测试: ${proxy.name} (resolved: ${state.proxyName}), testUrl=$testUrl');
      await proxyDelayTest(proxy, testUrl);
      // 读取实际延迟结果
      final url = state.testUrl.getSafeValue(testUrl);
      final delayMap = globalState.appState.delayMap[url];
      final delayValue = delayMap?[state.proxyName];
      debugPrint('[CompactNodeSelector] 单节点测试完成: ${proxy.name}, 延迟=${delayValue == null ? "null" : delayValue < 0 ? "超时" : "${delayValue}ms"}');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[CompactNodeSelector] 单节点测试失败: ${proxy.name} $e');
    }
  }
}

// ---------------------------------------------------------------
// Floating panel  (toolbar at BOTTOM so it is always visible
// even when the list is long and clips at the top)
// ---------------------------------------------------------------
class _NodePanel extends ConsumerWidget {
  final Group? group;
  final List<Group> allGroups;
  final String realSelected;
  final bool isTesting;
  final bool isRefreshing;
  final double maxListHeight;
  final void Function(Proxy) onSelectNode;
  final void Function(Proxy) onDelayTest;
  final VoidCallback onTest;
  final VoidCallback onRefresh;

  const _NodePanel({
    required this.group,
    required this.allGroups,
    required this.realSelected,
    required this.isTesting,
    required this.isRefreshing,
    required this.maxListHeight,
    required this.onSelectNode,
    required this.onDelayTest,
    required this.onTest,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 判断用户是否有有效套餐
    final subscription = ref.watch(subscriptionInfoProvider);
    final hasSubscription = subscription != null && subscription.planId > 0;
    // 演示模式：有节点但无套餐（使用演示订阅）
    final isDemoMode = ref.watch(isDemoModeProvider);
    final showRefresh = hasSubscription || isDemoMode;

    // Filter out DIRECT / REJECT / info-only / group-reference nodes
    final groupNames = allGroups.map((g) => g.name).toSet();
    final displayNodes = group?.all.where((p) => _isDisplayableNode(p, groupNames)).toList() ?? [];
    final isEmpty = displayNodes.isEmpty;

    // Toolbar at TOP — always visible even when empty
    final toolbar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            isEmpty ? '无可用节点' : '${displayNodes.length} 个节点',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
          ),
          const Spacer(),
          if (showRefresh) ...[
            _ActionBtn(
              icon: Icons.sync_rounded,
              label: '刷新订阅',
              loading: isRefreshing,
              onTap: isRefreshing ? null : onRefresh,
            ),
          ],
          if (!isEmpty) ...[
            if (showRefresh) const SizedBox(width: 6),
            _ActionBtn(
              icon: Icons.speed_rounded,
              label: '测试延迟',
              loading: isTesting,
              onTap: isTesting ? null : onTest,
            ),
          ],
        ],
      ),
    );

    // Empty state content
    final emptyContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 40,
              color: colorScheme.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            hasSubscription || isDemoMode
                ? '暂无节点\n请点击「刷新订阅」重新获取'
                : '暂无节点\n请先购买套餐以获取节点',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : colorScheme.outline.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toolbar at top — always visible
                toolbar,
                // Node list or empty state
                if (isEmpty)
                  emptyContent
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxListHeight),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      shrinkWrap: true,
                      itemCount: displayNodes.length,
                      itemBuilder: (context, index) {
                        final proxy = displayNodes[index];
                        return _NodeRow(
                          proxy: proxy,
                          isSelected: proxy.name == realSelected,
                          onTap: () => onSelectNode(proxy),
                          onDelayTest: () => onDelayTest(proxy),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Node row
// ---------------------------------------------------------------
class _NodeRow extends ConsumerWidget {
  final Proxy proxy;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelayTest;

  const _NodeRow({
    required this.proxy,
    required this.isSelected,
    required this.onTap,
    required this.onDelayTest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final delay = ref.watch(getDelayProvider(
      proxyName: proxy.name,
      testUrl: ref.read(appSettingProvider).testUrl,
    ));

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.18)
            : null,
        child: Row(
          children: [
            _FlagWidget(name: proxy.name, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                proxy.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontSize: 13,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelayTest,
              child: _DelayText(delay: delay),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded,
                  size: 16, color: colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Flag: image asset with colored-badge fallback
// ---------------------------------------------------------------
class _FlagWidget extends StatelessWidget {
  final String name;
  final double size;
  const _FlagWidget({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final code = _getRegionCode(name);
    if (code.isEmpty) {
      return Icon(Icons.language,
          size: size, color: Theme.of(context).colorScheme.primary);
    }
    return SizedBox(
      width: size * 1.4,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.asset(
          'assets/images/flags/$code.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _FallbackBadge(code: code, size: size),
        ),
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  final String code;
  final double size;
  const _FallbackBadge({required this.code, required this.size});

  @override
  Widget build(BuildContext context) {
    final bg = _fallbackColors[code] ?? Theme.of(context).colorScheme.primary;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(2)),
      child: Text(
        code.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Delay text
// ---------------------------------------------------------------
class _DelayText extends StatelessWidget {
  final int? delay;
  const _DelayText({this.delay});

  @override
  Widget build(BuildContext context) {
    if (delay == null) {
      return Text(
        '--',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.35),
              fontSize: 12,
            ),
      );
    }
    if (delay == 0) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Theme.of(context).colorScheme.primary),
      );
    }
    final color = utils.getDelayColor(delay);
    return Text(
      delay! < 0 ? '超时' : '${delay}ms',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
    );
  }
}

// ---------------------------------------------------------------
// Action button
// ---------------------------------------------------------------
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: colorScheme.primary),
              )
            else
              Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Empty state pill
// ---------------------------------------------------------------
class _EmptyPill extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 16, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).xboardNoAvailableNodes,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}