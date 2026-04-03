import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show XBoardSDK;
import 'package:fl_clash/xboard/domain/models/order.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:intl/intl.dart';

/// 订单管理弹窗
class OrderManagementDialog extends ConsumerStatefulWidget {
  const OrderManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const OrderManagementDialog(),
    );
  }

  @override
  ConsumerState<OrderManagementDialog> createState() =>
      _OrderManagementDialogState();
}

class _OrderManagementDialogState extends ConsumerState<OrderManagementDialog> {
  List<DomainOrder> _orders = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _cancelingOrders = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 按状态并行加载（每个~2KB vs 全量~407KB）
      final results = await Future.wait([
        XBoardSDK.instance.order.getOrders(status: 0), // 待支付
        XBoardSDK.instance.order.getOrders(status: 1), // 开通中
        XBoardSDK.instance.order.getOrders(status: 2), // 已取消
        XBoardSDK.instance.order.getOrders(status: 3), // 已完成
      ]);
      final orderModels = [...results[0], ...results[1], ...results[2], ...results[3]];
      final orders = orderModels
          .map((o) => DomainOrder(
                tradeNo: o.tradeNo ?? '',
                planId: o.planId ?? 0,
                period: o.period ?? '',
                totalAmount: (o.totalAmount ?? 0) / 100,
                status: OrderStatus.fromCode(o.status ?? 0),
                planName: o.orderPlan?.name,
                createdAt: o.createdAt ?? DateTime.now(),
              ))
          .toList();
      // 按创建时间降序
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  Future<void> _cancelOrder(DomainOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认取消'),
        content: Text('取消订单 ${order.tradeNo} 后，冻结的余额将被释放。确定要取消吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('取消订单'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelingOrders.add(order.tradeNo));
    try {
      final success =
          await XBoardSDK.instance.order.cancelOrder(order.tradeNo);
      if (success) {
        XBoardNotification.showSuccess('订单已取消，余额已释放');
        // 刷新用户余额
        ref.read(xboardUserProvider.notifier).refreshUserInfo();
        await _loadOrders();
      } else {
        XBoardNotification.showError('取消失败');
      }
    } catch (e) {
      XBoardNotification.showError('取消失败: $e');
    } finally {
      if (mounted) {
        setState(() => _cancelingOrders.remove(order.tradeNo));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width * 0.9).clamp(320.0, 520.0);
    final dialogHeight = (screenSize.height * 0.7).clamp(300.0, 560.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '订单管理',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20, color: colorScheme.primary),
                    onPressed: _isLoading ? null : _loadOrders,
                    tooltip: '刷新',
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 内容区
            Expanded(
              child: _buildContent(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text('暂无订单', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _OrderCard(
        order: _orders[index],
        isCanceling: _cancelingOrders.contains(_orders[index].tradeNo),
        onCancel: () => _cancelOrder(_orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DomainOrder order;
  final bool isCanceling;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.order,
    required this.isCanceling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _getStatusColor(colorScheme);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：套餐名 + 状态
          Row(
            children: [
              Expanded(
                child: Text(
                  order.planName ?? '套餐 #${order.planId}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 第二行：订单号 + 金额
          Row(
            children: [
              Expanded(
                child: Text(
                  '订单号: ${order.tradeNo}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '¥${order.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 第三行：时间 + 周期 + 操作
          Row(
            children: [
              Text(
                dateFormat.format(order.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getPeriodLabel(order.period),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              // 仅待支付的订单可以取消
              if (order.canCancel)
                SizedBox(
                  height: 28,
                  child: isCanceling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: onCancel,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('取消订单', style: TextStyle(fontSize: 12)),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    switch (order.status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.processing:
        return const Color(0xFF1565C0);
      case OrderStatus.canceled:
        return colorScheme.onSurfaceVariant;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.discounted:
        return Colors.teal;
    }
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'month_price':
        return '月付';
      case 'quarter_price':
        return '季付';
      case 'half_year_price':
        return '半年付';
      case 'year_price':
        return '年付';
      case 'two_year_price':
        return '两年付';
      case 'three_year_price':
        return '三年付';
      case 'onetime_price':
        return '一次性';
      default:
        return period;
    }
  }
}
