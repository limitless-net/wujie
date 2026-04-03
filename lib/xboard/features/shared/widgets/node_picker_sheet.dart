import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/common.dart' as proxies_common;
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';

// ============================================================
// 国旗 emoji 映射
// ============================================================
const _flagMap = <String, String>{
  '香港': '🇭🇰', 'HK': '🇭🇰', 'Hong Kong': '🇭🇰', 'hongkong': '🇭🇰',
  '台湾': '🇹🇼', 'TW': '🇹🇼', 'Taiwan': '🇹🇼',
  '日本': '🇯🇵', 'JP': '🇯🇵', 'Japan': '🇯🇵',
  '美国': '🇺🇸', 'US': '🇺🇸', 'USA': '🇺🇸', 'United States': '🇺🇸',
  '韩国': '🇰🇷', 'KR': '🇰🇷', 'Korea': '🇰🇷',
  '新加坡': '🇸🇬', 'SG': '🇸🇬', 'Singapore': '🇸🇬',
  '德国': '🇩🇪', 'DE': '🇩🇪', 'Germany': '🇩🇪',
  '英国': '🇬🇧', 'UK': '🇬🇧', 'GB': '🇬🇧', 'United Kingdom': '🇬🇧',
  '法国': '🇫🇷', 'FR': '🇫🇷', 'France': '🇫🇷',
  '加拿大': '🇨🇦', 'CA': '🇨🇦', 'Canada': '🇨🇦',
  '澳大利亚': '🇦🇺', 'AU': '🇦🇺', 'Australia': '🇦🇺',
  '印度': '🇮🇳', 'IN': '🇮🇳', 'India': '🇮🇳',
  '俄罗斯': '🇷🇺', 'RU': '🇷🇺', 'Russia': '🇷🇺',
  '巴西': '🇧🇷', 'BR': '🇧🇷', 'Brazil': '🇧🇷',
  '荷兰': '🇳🇱', 'NL': '🇳🇱', 'Netherlands': '🇳🇱',
  '土耳其': '🇹🇷', 'TR': '🇹🇷', 'Turkey': '🇹🇷',
  '泰国': '🇹🇭', 'TH': '🇹🇭', 'Thailand': '🇹🇭',
  '越南': '🇻🇳', 'VN': '🇻🇳', 'Vietnam': '🇻🇳',
  '菲律宾': '🇵🇭', 'PH': '🇵🇭', 'Philippines': '🇵🇭',
  '马来西亚': '🇲🇾', 'MY': '🇲🇾', 'Malaysia': '🇲🇾',
  '印尼': '🇮🇩', 'ID': '🇮🇩', 'Indonesia': '🇮🇩',
  '阿根廷': '🇦🇷', 'AR': '🇦🇷', 'Argentina': '🇦🇷',
  '以色列': '🇮🇱', 'IL': '🇮🇱', 'Israel': '🇮🇱',
  '爱尔兰': '🇮🇪', 'IE': '🇮🇪', 'Ireland': '🇮🇪',
  '意大利': '🇮🇹', 'IT': '🇮🇹', 'Italy': '🇮🇹',
  '西班牙': '🇪🇸', 'ES': '🇪🇸', 'Spain': '🇪🇸',
  '瑞士': '🇨🇭', 'CH': '🇨🇭', 'Switzerland': '🇨🇭',
  '波兰': '🇵🇱', 'PL': '🇵🇱', 'Poland': '🇵🇱',
  '墨西哥': '🇲🇽', 'MX': '🇲🇽', 'Mexico': '🇲🇽',
  '南非': '🇿🇦', 'ZA': '🇿🇦', 'South Africa': '🇿🇦',
  '智利': '🇨🇱', 'CL': '🇨🇱', 'Chile': '🇨🇱',
  '哥伦比亚': '🇨🇴', 'CO': '🇨🇴', 'Colombia': '🇨🇴',
  '乌克兰': '🇺🇦', 'UA': '🇺🇦', 'Ukraine': '🇺🇦',
  '柬埔寨': '🇰🇭', 'KH': '🇰🇭', 'Cambodia': '🇰🇭',
  '缅甸': '🇲🇲', 'MM': '🇲🇲', 'Myanmar': '🇲🇲',
  '尼日利亚': '🇳🇬', 'NG': '🇳🇬', 'Nigeria': '🇳🇬',
  '埃及': '🇪🇬', 'EG': '🇪🇬', 'Egypt': '🇪🇬',
  '迪拜': '🇦🇪', 'AE': '🇦🇪', 'UAE': '🇦🇪',
};

String _getFlag(String name) {
  for (final entry in _flagMap.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return '🌐';
}

bool _isDisplayableNode(Proxy proxy, Set<String> groupNames) {
  final n = proxy.name;
  if (n == 'DIRECT' || n == 'REJECT') return false;
  if (n.contains('剩余流量') || n.contains('套餐到期') ||
      n.contains('过期时间') || n.contains('到期时间') ||
      n.contains('重置') || n.contains('入站') ||
      n.contains('Remaining') || n.contains('Expire') || n.contains('Reset')) {
    return false;
  }
  if (n.contains('购买') || n.contains('官网') || n.contains('https://')) {
    return false;
  }
  if (groupNames.contains(n)) return false;
  return true;
}

// ============================================================
// 查找当前代理组（公共逻辑，供多处复用）
// ============================================================
Group? _findCurrentGroup(
    List<Group> groups, Map<String, String> selectedMap, Mode mode) {
  if (groups.isEmpty) return null;
  Group? currentGroup;

  if (mode == Mode.global) {
    currentGroup = groups.firstWhere(
      (g) => g.name == GroupName.GLOBAL.name,
      orElse: () => groups.first,
    );
  } else if (mode == Mode.rule) {
    for (final group in groups) {
      if (group.hidden == true) continue;
      if (group.name == GroupName.GLOBAL.name) continue;
      final sel = selectedMap[group.name];
      if (sel != null && sel.isNotEmpty) {
        final refGroup = groups.firstWhere((g) => g.name == sel, orElse: () => group);
        if (refGroup.name == sel && refGroup.type == GroupType.URLTest) {
          currentGroup = refGroup;
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
      if (currentGroup.now != null && currentGroup.now!.isNotEmpty) {
        final nowVal = currentGroup.now!;
        final refG2 =
            groups.firstWhere((g) => g.name == nowVal, orElse: () => currentGroup!);
        if (refG2.name == nowVal && refG2.type == GroupType.URLTest) {
          currentGroup = refG2;
        }
      }
    }
  }
  return currentGroup;
}

// ============================================================
// 弹出下拉框（锚定到 anchor widget 下方）
// ============================================================
Future<void> showNodePickerSheet(BuildContext context, WidgetRef ref,
    [Rect? anchorRect]) {
  // 如果没传 anchorRect，则居中显示
  return showDialog(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => _NodePickerPopup(anchorRect: anchorRect),
  );
}

class _NodePickerPopup extends ConsumerStatefulWidget {
  final Rect? anchorRect;
  const _NodePickerPopup({this.anchorRect});

  @override
  ConsumerState<_NodePickerPopup> createState() => _NodePickerPopupState();
}

class _NodePickerPopupState extends ConsumerState<_NodePickerPopup> {
  bool _isRefreshing = false;
  bool _isTesting = false;

  @override
  Widget build(BuildContext context) {
    try {
      return _buildContent(context);
    } catch (_) {
      // 数据未就绪时避免红屏
      return _buildEmptyDialog(context);
    }
  }

  Widget _buildContent(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );

    final currentGroup = _findCurrentGroup(groups, selectedMap, mode);

    if (currentGroup == null || currentGroup.all.isEmpty) {
      return _buildEmptyDialog(context);
    }

    final groupName = currentGroup.name;
    final groupType = currentGroup.type;
    final allGroupNames = groups.map((g) => g.name).toSet();
    final proxies = currentGroup.all
        .where((p) => _isDisplayableNode(p, allGroupNames))
        .toList();

    final selectedName = selectedMap[groupName] ?? "";
    final realSelected = groupType == GroupType.URLTest
        ? (currentGroup.now ?? "")
        : currentGroup.getCurrentSelectedName(selectedName);

    final colorScheme = Theme.of(context).colorScheme;
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final cardWidth = (screenW * 0.82).clamp(280.0, 400.0);
    final listMaxH = (proxies.length * 48.0).clamp(48.0, screenH * 0.42);
    final totalMaxH = listMaxH + 96; // header + divider + actions

    final anchor = widget.anchorRect;

    Widget card = Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(maxHeight: totalMaxH),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // === 工具栏：更新订阅 + 测试延迟 ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.dns_outlined,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).xboardProxy,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${proxies.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                  ),
                  const Spacer(),
                  // 更新订阅
                  _ActionIconBtn(
                    icon: _isRefreshing ? null : Icons.sync_rounded,
                    loading: _isRefreshing,
                    tooltip: AppLocalizations.of(context).xboardRefresh,
                    onTap: _isRefreshing ? null : () => _refreshSub(ref),
                  ),
                  // 测试延迟
                  _ActionIconBtn(
                    icon: _isTesting ? null : Icons.speed_rounded,
                    loading: _isTesting,
                    tooltip: AppLocalizations.of(context).delay,
                    onTap: _isTesting
                        ? null
                        : () => _testDelay(proxies, currentGroup.testUrl),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            // === 节点列表 ===
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: proxies.length,
                itemBuilder: (context, index) {
                  final proxy = proxies[index];
                  final isSelected = proxy.name == realSelected;
                  return _NodeTile(
                    proxy: proxy,
                    isSelected: isSelected,
                    onTap: () => _onNodeTap(
                        context, ref, groupName, groupType, proxy),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    // 如果有锚点，定位在药丸下方居中
    if (anchor != null) {
      final top = anchor.bottom + 8;
      final left = (anchor.left + anchor.right) / 2 - cardWidth / 2;
      final clampedLeft = left.clamp(12.0, screenW - cardWidth - 12);
      final clampedTop = top.clamp(12.0, screenH - totalMaxH - 12);

      return Stack(
        children: [
          // 透明点击区域关闭
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            top: clampedTop,
            left: clampedLeft,
            child: card,
          ),
        ],
      );
    }

    // 没有锚点则居中
    return Center(child: card);
  }

  void _refreshSub(WidgetRef ref) async {
    final wasRunning = ref.read(runTimeProvider) != null;
    setState(() => _isRefreshing = true);
    try {
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
      if (mounted && wasRunning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('订阅已更新，代理连接已断开，请重新连接'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _testDelay(List<Proxy> proxies, String? testUrl) async {
    setState(() => _isTesting = true);
    try {
      await proxies_common.delayTest(proxies, testUrl);
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _onNodeTap(
    BuildContext context,
    WidgetRef ref,
    String groupName,
    GroupType groupType,
    Proxy proxy,
  ) {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;

    if (isComputedSelected || isSelector) {
      final currentProxyName = ref.read(getProxyNameProvider(groupName));
      final nextProxyName = switch (isComputedSelected) {
        true => currentProxyName == proxy.name ? "" : proxy.name,
        false => proxy.name,
      };
      final appController = globalState.appController;
      appController.updateCurrentSelectedMap(groupName, nextProxyName);
      appController.changeProxyDebounce(groupName, nextProxyName);
    }

    Navigator.of(context).pop();
  }

  Widget _buildEmptyDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 40,
                  color: colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).xboardNoAvailableNodes,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 小图标按钮（工具栏用）
// ============================================================
class _ActionIconBtn extends StatelessWidget {
  final IconData? icon;
  final bool loading;
  final String tooltip;
  final VoidCallback? onTap;
  const _ActionIconBtn(
      {this.icon, this.loading = false, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              : Icon(icon, size: 20, color: colorScheme.primary),
        ),
      ),
    );
  }
}

// ============================================================
// 节点行
// ============================================================
class _NodeTile extends ConsumerWidget {
  final Proxy proxy;
  final bool isSelected;
  final VoidCallback onTap;

  const _NodeTile({
    required this.proxy,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final delay = ref.watch(getDelayProvider(
      proxyName: proxy.name,
      testUrl: ref.read(appSettingProvider).testUrl,
    ));
    final flag = _getFlag(proxy.name);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.25)
            : null,
        child: Row(
          children: [
            // 国旗
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            // 节点名
            Expanded(
              child: Text(
                proxy.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 延迟
            _buildDelay(context, delay),
            // 选中对勾
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDelay(BuildContext context, int? delay) {
    if (delay == null) {
      return Text(
        '--',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
      );
    }
    if (delay == 0) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final color = utils.getDelayColor(delay);
    return Text(
      delay < 0 ? '超时' : '${delay}ms',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
