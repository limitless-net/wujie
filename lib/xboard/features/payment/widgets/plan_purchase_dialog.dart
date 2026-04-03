import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show XBoardSDK, CouponModel;
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' as sdk show XBoardException;
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import '../widgets/period_selector.dart';
import '../widgets/coupon_input_section.dart';
import '../widgets/price_summary_card.dart';
import '../utils/price_calculator.dart';

final _logger = FileLogger('plan_purchase_dialog.dart');

/// 购买流程的内部阶段
enum _PurchasePhase {
  selectPeriod,   // 选择周期（初始页面）
  processing,     // 处理中（创建订单、取消旧订单等）
  selectPayment,  // 选择支付方式
  waitingPayment, // 等待支付完成
  success,        // 购买成功
  error,          // 出错
}

/// 弹窗式套餐购买 - 所有流程在弹窗内完成
class PlanPurchaseDialog extends ConsumerStatefulWidget {
  final DomainPlan plan;

  const PlanPurchaseDialog({super.key, required this.plan});

  /// 显示购买弹窗
  static Future<void> show(BuildContext context, DomainPlan plan) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 640),
          child: PlanPurchaseDialog(plan: plan),
        ),
      ),
    );
  }

  @override
  ConsumerState<PlanPurchaseDialog> createState() => _PlanPurchaseDialogState();
}

class _PlanPurchaseDialogState extends ConsumerState<PlanPurchaseDialog> {
  // -- 流程阶段 --
  _PurchasePhase _phase = _PurchasePhase.selectPeriod;
  String _processingMessage = '';
  String _errorMessage = '';

  // -- 周期 & 优惠券 --
  String? _selectedPeriod;
  bool _showCouponInput = false;
  final _couponController = TextEditingController();
  bool _isCouponValidating = false;
  bool? _isCouponValid;
  String? _couponErrorMessage;
  String? _couponCode;
  int? _couponType;
  int? _couponValue;
  double? _discountAmount;
  double? _finalPrice;

  // -- 用户余额 --
  double? _userBalance;

  // -- 支付相关 --
  String? _tradeNo;
  List<DomainPaymentMethod> _paymentMethods = [];
  String? _paymentUrl;

  // -- 自动轮询 --
  Timer? _pollTimer;
  int _pollCount = 0;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    ref.read(xboardPaymentProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserBalance();
    });
  }

  @override
  void dispose() {
    _stopPolling();
    _couponController.dispose();
    super.dispose();
  }

  // ========== 自动轮询 ==========

  void _startPolling() {
    _stopPolling();
    _pollCount = 0;
    _isPolling = true;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOrderStatus());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
  }

  /// 处理关闭操作，如果在支付等待阶段则弹出确认对话框
  Future<void> _handleClose() async {
    if (_phase == _PurchasePhase.waitingPayment) {
      final shouldClose = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('支付进行中'),
            ],
          ),
          content: const Text(
            '系统正在自动检测支付状态，关闭后将停止检测。\n\n'
            '您的订单不会丢失，可以稍后在订单列表中查看支付结果。\n\n'
            '确定要关闭吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('继续等待'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              child: const Text('确认关闭'),
            ),
          ],
        ),
      );
      if (shouldClose == true && mounted) {
        _stopPolling();
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 处理取消支付：确认后关闭订单
  Future<void> _handleCancelPayment() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('取消支付'),
          ],
        ),
        content: const Text(
          '确定要取消支付吗？\n\n'
          '取消后当前订单将被关闭，您可以重新选择套餐和支付方式进行购买。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续支付'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (shouldCancel == true && mounted) {
      _stopPolling();
      // 调用API关闭订单
      if (_tradeNo != null) {
        setState(() { _phase = _PurchasePhase.processing; _processingMessage = '正在取消订单...'; });
        try {
          await XBoardSDK.instance.order.cancelOrder(_tradeNo!);
          _logger.debug('[取消支付] 订单已取消: $_tradeNo');
        } catch (e) {
          _logger.debug('[取消支付] 取消订单失败: $e');
        }
      }
      if (mounted) {
        _backToSelectPeriod();
        XBoardNotification.showInfo('订单已取消，您可以重新选择套餐');
      }
    }
  }

  Future<void> _pollOrderStatus() async {
    if (!mounted || _phase != _PurchasePhase.waitingPayment) {
      _stopPolling();
      return;
    }
    _pollCount++;
    _logger.debug('[自动轮询] 第$_pollCount次检查, tradeNo=$_tradeNo');
    try {
      final paid = await _checkOrderPaid();
      if (!mounted) return;
      if (paid) {
        _stopPolling();
        await _onPaymentComplete();
      }
    } catch (e) {
      _logger.debug('[自动轮询] 查询出错: $e');
    }
    // 超过60次（3分钟）后降低频率到10秒一次
    if (_pollCount == 60 && _pollTimer != null) {
      _stopPolling();
      _isPolling = true;
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollOrderStatus());
    }
  }

  // ========== 数据加载 ==========

  Future<void> _loadUserBalance() async {
    try {
      await ref.read(xboardUserProvider.notifier).refreshUserInfo();
      final userInfo = ref.read(xboardUserProvider).userInfo;
      if (mounted) setState(() => _userBalance = userInfo?.balanceInYuan);
    } catch (e) {
      _logger.debug('[购买弹窗] 加载余额失败: $e');
    }
  }

  List<Map<String, dynamic>> _getAvailablePeriods(BuildContext context) {
    final List<Map<String, dynamic>> periods = [];
    final plan = widget.plan;
    final l10n = AppLocalizations.of(context);

    if (plan.monthlyPrice != null) periods.add({'period': 'month_price', 'label': l10n.xboardMonthlyPayment, 'price': plan.monthlyPrice!, 'description': l10n.xboardMonthlyRenewal});
    if (plan.quarterlyPrice != null) periods.add({'period': 'quarter_price', 'label': l10n.xboardQuarterlyPayment, 'price': plan.quarterlyPrice!, 'description': l10n.xboardThreeMonthCycle});
    if (plan.halfYearlyPrice != null) periods.add({'period': 'half_year_price', 'label': l10n.xboardHalfYearlyPayment, 'price': plan.halfYearlyPrice!, 'description': l10n.xboardSixMonthCycle});
    if (plan.yearlyPrice != null) periods.add({'period': 'year_price', 'label': l10n.xboardYearlyPayment, 'price': plan.yearlyPrice!, 'description': l10n.xboardTwelveMonthCycle});
    if (plan.twoYearPrice != null) periods.add({'period': 'two_year_price', 'label': l10n.xboardTwoYearPayment, 'price': plan.twoYearPrice!, 'description': l10n.xboardTwentyFourMonthCycle});
    if (plan.threeYearPrice != null) periods.add({'period': 'three_year_price', 'label': l10n.xboardThreeYearPayment, 'price': plan.threeYearPrice!, 'description': l10n.xboardThirtySixMonthCycle});
    if (plan.onetimePrice != null) periods.add({'period': 'onetime_price', 'label': l10n.xboardOneTimePayment, 'price': plan.onetimePrice!, 'description': l10n.xboardBuyoutPlan});
    return periods;
  }

  double _getCurrentPrice() {
    if (_selectedPeriod == null) return 0.0;
    final periods = _getAvailablePeriods(context);
    final selected = periods.firstWhere((p) => p['period'] == _selectedPeriod, orElse: () => {});
    return selected['price']?.toDouble() ?? 0.0;
  }

  // ========== 优惠券 ==========

  Future<void> _validateCoupon() async {
    if (_couponController.text.trim().isEmpty) { _clearCoupon(); return; }
    setState(() { _isCouponValidating = true; _isCouponValid = null; _couponErrorMessage = null; });
    try {
      final code = _couponController.text.trim();
      final couponData = await XBoardSDK.instance.order.checkCoupon(code, widget.plan.id)
          .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('网络超时，请检查网络后重试'));
      if (couponData != null && mounted) {
        _applyCoupon(code, couponData);
      } else if (mounted) {
        _setCouponInvalid();
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        XBoardNotification.showError('网络超时，请检查网络后重试');
        setState(() { _isCouponValid = false; _couponErrorMessage = null; _clearCouponData(); });
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is sdk.XBoardException ? e.message : '验证失败，请重试';
        XBoardNotification.showError(errorMsg);
        setState(() { _isCouponValid = false; _couponErrorMessage = null; _clearCouponData(); });
      }
    } finally {
      if (mounted) setState(() => _isCouponValidating = false);
    }
  }

  void _applyCoupon(String code, CouponModel couponData) {
    final currentPrice = _getCurrentPrice();
    final discountAmount = PriceCalculator.calculateDiscountAmount(currentPrice, couponData.type, couponData.value);
    final finalPrice = currentPrice - discountAmount;
    setState(() {
      _isCouponValid = true; _couponCode = code; _couponType = couponData.type; _couponValue = couponData.value;
      _discountAmount = discountAmount; _finalPrice = finalPrice > 0 ? finalPrice : 0; _couponErrorMessage = null;
    });
  }

  void _setCouponInvalid() {
    XBoardNotification.showError(AppLocalizations.of(context).xboardInvalidOrExpiredCoupon);
    setState(() { _isCouponValid = false; _couponErrorMessage = null; _clearCouponData(); });
  }

  void _clearCoupon() { if (mounted) setState(() { _isCouponValid = null; _couponErrorMessage = null; _clearCouponData(); }); }

  void _clearCouponData() { _discountAmount = null; _finalPrice = null; _couponCode = null; _couponType = null; _couponValue = null; }

  void _recalculateDiscount() {
    if (_couponType == null || _couponValue == null) return;
    final currentPrice = _getCurrentPrice();
    final discountAmount = PriceCalculator.calculateDiscountAmount(currentPrice, _couponType, _couponValue);
    setState(() { _discountAmount = discountAmount; _finalPrice = PriceCalculator.calculateFinalPrice(currentPrice, _couponType, _couponValue); });
  }

  // ========== 购买流程（弹窗内完成） ==========

  Future<void> _proceedToPurchase() async {
    if (_selectedPeriod == null) {
      XBoardNotification.showError('请先选择付款周期');
      // 自动弹出周期选择弹窗
      final periods = _getAvailablePeriods(context);
      if (periods.isNotEmpty) {
        _showPeriodPickerDialog(periods);
      }
      return;
    }

    try {
      // 进入处理阶段
      setState(() { _phase = _PurchasePhase.processing; _processingMessage = '正在准备订单...'; });

      _logger.debug('[购买弹窗] 开始购买流程, 套餐ID: ${widget.plan.id}, 周期: $_selectedPeriod');

      // 创建订单
      setState(() => _processingMessage = '正在创建订单...');
      final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
      _tradeNo = await paymentNotifier.createOrder(
        planId: widget.plan.id,
        period: _selectedPeriod!,
        couponCode: _couponCode,
      );

      if (_tradeNo == null) {
        final errorMessage = ref.read(userUIStateProvider).errorMessage;
        throw Exception('订单创建失败: $errorMessage');
      }

      if (!mounted) return;
      _logger.debug('[购买弹窗] 订单创建成功: $_tradeNo');

      final preOrderBalance = _userBalance ?? 0;
      final displayFinalPrice = _finalPrice ?? _getCurrentPrice();
      final balanceToUse = preOrderBalance > 0
          ? (preOrderBalance > displayFinalPrice ? displayFinalPrice : preOrderBalance)
          : 0.0;
      final actualPayAmount = displayFinalPrice - balanceToUse;

      _logger.debug('[购买弹窗] 实付: $actualPayAmount (价格: $displayFinalPrice, 余额抵扣: $balanceToUse)');

      // 余额完全抵扣
      if (actualPayAmount <= 0) {
        setState(() => _processingMessage = '余额支付中...');
        var methods = ref.read(xboardAvailablePaymentMethodsProvider);
        if (methods.isEmpty) {
          await ref.read(xboardPaymentProvider.notifier).loadPaymentMethods();
          methods = ref.read(xboardAvailablePaymentMethodsProvider);
        }
        final methodId = methods.isNotEmpty ? methods.first.id.toString() : '0';
        final result = await paymentNotifier.submitPayment(tradeNo: _tradeNo!, method: methodId);
        if (result != null && result['type'] == -1 && result['data'] == true) {
          await _onPaymentComplete();
          return;
        }
        throw Exception('余额支付未成功，请重试');
      }

      // 需要实际支付 - 加载支付方式
      setState(() => _processingMessage = '正在加载支付方式...');
      _paymentMethods = ref.read(xboardAvailablePaymentMethodsProvider);
      if (_paymentMethods.isEmpty) {
        await ref.read(xboardPaymentProvider.notifier).loadPaymentMethods();
        _paymentMethods = ref.read(xboardAvailablePaymentMethodsProvider);
      }
      if (_paymentMethods.isEmpty) throw Exception('暂无可用的支付方式');

      if (!mounted) return;

      // 单一支付方式直接提交
      if (_paymentMethods.length == 1) {
        await _submitWithMethod(_paymentMethods.first);
        return;
      }

      // 多支付方式显示选择界面
      setState(() => _phase = _PurchasePhase.selectPayment);
    } catch (e) {
      _logger.error('购买流程出错: $e');
      if (mounted) {
        setState(() { _phase = _PurchasePhase.error; _errorMessage = _friendlyError(e); });
      }
    }
  }

  Future<void> _submitWithMethod(DomainPaymentMethod method) async {
    if (!mounted) return;
    setState(() { _phase = _PurchasePhase.processing; _processingMessage = '正在发起支付...'; });

    try {
      _logger.debug('[支付] 提交: $_tradeNo, 方式: ${method.id}');
      final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
      final result = await paymentNotifier.submitPayment(tradeNo: _tradeNo!, method: method.id.toString());
      if (result == null) throw Exception('支付请求返回空结果');
      if (!mounted) return;

      final paymentType = result['type'] as int? ?? 0;
      final paymentData = result['data'];

      if (paymentType == -1) {
        if (paymentData == true) {
          await _onPaymentComplete();
        } else {
          throw Exception('余额支付未成功');
        }
      } else if (paymentData != null && paymentData is String && paymentData.isNotEmpty) {
        _paymentUrl = paymentData;
        setState(() => _phase = _PurchasePhase.waitingPayment);
        _startPolling();
        _launchPaymentUrl(paymentData);
      } else {
        throw Exception('未获取到有效支付数据');
      }
    } catch (e) {
      _logger.error('支付提交出错: $e');
      if (mounted) setState(() { _phase = _PurchasePhase.error; _errorMessage = _friendlyError(e); });
    }
  }

  Future<void> _onPaymentComplete() async {
    if (!mounted) return;
    _logger.info('[支付成功]');
    try {
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfoAfterPayment();
    } catch (e) {
      _logger.debug('[支付成功] 刷新订阅信息失败: $e');
    }
    // 等待节点配置生效后触发延迟测试（节点需要时间同步）
    Future.delayed(const Duration(seconds: 15), () {
      autoLatencyService.testCurrentGroupNodes();
    });
    if (mounted) setState(() => _phase = _PurchasePhase.success);
  }

  /// 查询订单状态，确认是否已支付
  Future<bool> _checkOrderPaid() async {
    if (_tradeNo == null) return false;
    try {
      final order = await XBoardSDK.instance.order.getOrder(_tradeNo!);
      if (order == null) return false;
      // status: 0=待付款, 1=开通中, 2=已取消, 3=已完成, 4=已折抵
      final status = order.status ?? 0;
      _logger.debug('[订单查询] tradeNo=$_tradeNo, status=$status');
      return status == 1 || status == 3 || status == 4;
    } catch (e) {
      _logger.error('[订单查询] 查询失败: $e');
      return false;
    }
  }

  Future<void> _launchPaymentUrl(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      final uri = Uri.parse(url);
      // 移动端使用应用内浏览器打开支付页，桌面端使用外部浏览器
      final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      final mode = isDesktop ? LaunchMode.externalApplication : LaunchMode.inAppBrowserView;
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode);
      }
    } catch (e) {
      _logger.error('打开支付链接失败: $e');
    }
  }

  void _backToSelectPeriod() {
    _stopPolling();
    setState(() { _phase = _PurchasePhase.selectPeriod; _errorMessage = ''; });
  }

  // ========== UI 构建 ==========

  /// 从异常中提取用户友好的错误信息
  String _friendlyError(Object e) {
    var msg = e.toString();
    // 移除 "Exception: " 前缀
    msg = msg.replaceFirst(RegExp(r'^Exception:\s*'), '');
    // 移除 "订单创建失败: " 前缀
    msg = msg.replaceFirst(RegExp(r'^订单创建失败:\s*'), '');
    // 移除 "XBoardException(xxx): " 前缀
    msg = msg.replaceFirst(RegExp(r'XBoardException\(\d+\):\s*'), '');
    return msg.isEmpty ? '操作失败，请稍后重试' : msg;
  }

  String _formatTraffic(double transferEnable) {
    if (transferEnable >= 1024) return '${(transferEnable / 1024).toStringAsFixed(1)}TB';
    return '${transferEnable.toStringAsFixed(0)}GB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plan = widget.plan;

    return PopScope(
      canPop: _phase != _PurchasePhase.waitingPayment,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(colorScheme, plan),
          Flexible(child: _buildPhaseContent(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, DomainPlan plan) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: colorScheme.onPrimary, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(plan.name, style: textTheme.titleSmall?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _handleClose,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: colorScheme.onPrimary.withValues(alpha: 0.7), size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: [
              _HeaderChip(icon: Icons.cloud_download_outlined, label: _formatTraffic(plan.transferQuota.toDouble()), colorScheme: colorScheme),
              if (plan.speedLimit != null) _HeaderChip(icon: Icons.speed_rounded, label: '${plan.speedLimit} Mbps', colorScheme: colorScheme),
              if (plan.deviceLimit != null) _HeaderChip(icon: Icons.devices_rounded, label: '${plan.deviceLimit}台设备', colorScheme: colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(ColorScheme colorScheme) {
    switch (_phase) {
      case _PurchasePhase.selectPeriod:
        return _buildSelectPeriodContent(colorScheme);
      case _PurchasePhase.processing:
        return _buildProcessingContent(colorScheme);
      case _PurchasePhase.selectPayment:
        return _buildSelectPaymentContent(colorScheme);
      case _PurchasePhase.waitingPayment:
        return _buildWaitingPaymentContent(colorScheme);
      case _PurchasePhase.success:
        return _buildSuccessContent(colorScheme);
      case _PurchasePhase.error:
        return _buildErrorContent(colorScheme);
    }
  }

  // -- 阶段1: 选择周期 --
  Widget _buildSelectPeriodContent(ColorScheme colorScheme) {
    final periods = _getAvailablePeriods(context);
    final currentPrice = _getCurrentPrice();
    final hasDiscount = _discountAmount != null && _discountAmount! > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 周期选择 — 下拉选择器
                _buildPeriodSelector(colorScheme, periods),
                const SizedBox(height: 10),
                // 优惠券 — 默认折叠，点击展开
                _buildCollapsibleCoupon(colorScheme),
                // 价格明细 — 仅在有折扣/优惠时展示
                if (_selectedPeriod != null && hasDiscount) ...[
                  const SizedBox(height: 10),
                  PriceSummaryCard(
                    originalPrice: currentPrice,
                    finalPrice: _finalPrice,
                    discountAmount: _discountAmount,
                    userBalance: _userBalance,
                  ),
                ],
              ],
            ),
          ),
        ),
        // 底部结算栏：价格 + 确认按钮
        _buildCheckoutBar(colorScheme, currentPrice),
      ],
    );
  }

  /// 折叠式优惠券区域
  Widget _buildCollapsibleCoupon(ColorScheme colorScheme) {
    // 如果已验证过优惠券或已展开输入框
    if (_showCouponInput || _isCouponValid != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CouponInputSection(
            controller: _couponController,
            isValidating: _isCouponValidating,
            isValid: _isCouponValid,
            errorMessage: _couponErrorMessage,
            discountAmount: _discountAmount,
            onValidate: _validateCoupon,
            onChanged: _clearCoupon,
          ),
        ],
      );
    }

    // 折叠状态 — 紧凑链接
    return GestureDetector(
      onTap: () => setState(() => _showCouponInput = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined, size: 16, color: colorScheme.tertiary),
            const SizedBox(width: 8),
            Text(
              '有优惠券？点击使用',
              style: TextStyle(fontSize: 13, color: colorScheme.tertiary, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.tertiary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  /// 底部结算栏 — 电商风格：左侧价格 + 右侧按钮
  Widget _buildCheckoutBar(ColorScheme colorScheme, double currentPrice) {
    final displayPrice = _finalPrice ?? currentPrice;
    final hasBalance = _userBalance != null && _userBalance! > 0;
    final balanceToUse = hasBalance
        ? (_userBalance! > displayPrice ? displayPrice : _userBalance!)
        : 0.0;
    final actualPay = displayPrice - balanceToUse;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.15))),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 左侧价格信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('¥', style: TextStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      Text(
                        actualPay.toStringAsFixed(2),
                        style: TextStyle(fontSize: 20, color: colorScheme.primary, fontWeight: FontWeight.bold, height: 1.1),
                      ),
                    ],
                  ),
                  if (balanceToUse > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '余额抵扣 ¥${balanceToUse.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      ),
                    ),
                  if (_discountAmount != null && _discountAmount! > 0)
                    Text(
                      '已优惠 ¥${_discountAmount!.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 10, color: colorScheme.tertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 右侧确认按钮
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: _proceedToPurchase,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  AppLocalizations.of(context).xboardConfirmPurchase,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 周期下拉选择器 — 点击展开底部列表
  Widget _buildPeriodSelector(ColorScheme colorScheme, List<Map<String, dynamic>> periods) {
    final textTheme = Theme.of(context).textTheme;

    // 当前选中的周期信息
    Map<String, dynamic>? selectedInfo;
    if (_selectedPeriod != null) {
      selectedInfo = periods.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p?['period'] == _selectedPeriod,
        orElse: () => null,
      );
    }

    final hasSelection = selectedInfo != null;
    final displayLabel = hasSelection ? selectedInfo!['label'] as String : '请选择';
    final displayPrice = hasSelection ? (selectedInfo!['price']?.toDouble() ?? 0.0) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).xboardSelectPaymentPeriod,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showPeriodSheet(periods),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasSelection
                    ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasSelection
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayLabel,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                            color: hasSelection ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (displayPrice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '¥${displayPrice.toStringAsFixed(displayPrice == displayPrice.roundToDouble() ? 0 : 2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 弹出周期选择弹窗
  void _showPeriodSheet(List<Map<String, dynamic>> periods) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context).xboardSelectPaymentPeriod,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: periods.map((period) {
                      final isSelected = _selectedPeriod == period['period'];
                      final price = period['price']?.toDouble() ?? 0.0;
                      final label = period['label'] as String;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Material(
                          color: isSelected
                              ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              setState(() {
                                _selectedPeriod = period['period'];
                                if (_couponCode != null) _recalculateDiscount();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '¥${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.check_circle_rounded, size: 18, color: colorScheme.primary),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 自动弹出周期选择（用于未选周期直接点购买时的提示）
  void _showPeriodPickerDialog(List<Map<String, dynamic>> periods) {
    _showPeriodSheet(periods);
  }

  // -- 阶段2: 处理中 --
  Widget _buildProcessingContent(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40, height: 40,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.primary),
          ),
          const SizedBox(height: 18),
          Text(_processingMessage, style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // -- 阶段3: 选择支付方式 --
  Widget _buildSelectPaymentContent(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.payment_rounded, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('选择支付方式', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              // 紧凑支付方式列表
              ..._paymentMethods.map((method) => _buildPaymentMethodTile(method, colorScheme)),
            ],
          ),
        ),
        // 底部返回链接
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextButton.icon(
            onPressed: _backToSelectPeriod,
            icon: Icon(Icons.arrow_back_rounded, size: 16, color: colorScheme.onSurfaceVariant),
            label: Text('返回修改', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(DomainPaymentMethod method, ColorScheme colorScheme) {
    IconData icon;
    Color iconColor;
    if (method.name.contains('支付宝') || method.name.toLowerCase().contains('alipay')) {
      icon = Icons.account_balance_wallet;
      iconColor = const Color(0xFF1677FF);
    } else if (method.name.contains('微信') || method.name.toLowerCase().contains('wechat')) {
      icon = Icons.chat_bubble;
      iconColor = const Color(0xFF07C160);
    } else if (method.name.toLowerCase().contains('usdt') || method.name.toLowerCase().contains('crypto')) {
      icon = Icons.currency_bitcoin;
      iconColor = const Color(0xFF26A17B);
    } else {
      icon = Icons.payment;
      iconColor = colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _submitWithMethod(method),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(method.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                ),
                Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- 阶段4: 等待支付 --
  Widget _buildWaitingPaymentContent(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 支付等待动画
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 52, height: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              Icon(Icons.payment_rounded, size: 24, color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 14),
          Text('等待支付完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          // 自动检测提示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 10, height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '自动检测支付状态中...',
                style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 操作按钮区
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                if (_paymentUrl != null)
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () => _launchPaymentUrl(_paymentUrl!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('重新打开支付页面', style: TextStyle(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () async {
                      setState(() { _phase = _PurchasePhase.processing; _processingMessage = '正在确认支付结果...'; });
                      _stopPolling();
                      try {
                        final paid = await _checkOrderPaid();
                        if (!mounted) return;
                        if (paid) {
                          await _onPaymentComplete();
                        } else {
                          _startPolling();
                          setState(() { _phase = _PurchasePhase.waitingPayment; });
                          XBoardNotification.showError('订单尚未支付，请先完成付款');
                        }
                      } catch (e) {
                        _startPolling();
                        if (mounted) setState(() { _phase = _PurchasePhase.waitingPayment; });
                        XBoardNotification.showError('确认失败，请稍后重试');
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('我已完成支付', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _handleCancelPayment,
            child: Text('取消支付', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  // -- 阶段5: 成功 --
  Widget _buildSuccessContent(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 40),
          ),
          const SizedBox(height: 16),
          Text('购买成功', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.onSurface), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('套餐已成功购买，订阅已自动更新',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (context.mounted) context.go('/');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('好的', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // -- 阶段6: 错误 --
  Widget _buildErrorContent(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 40),
          const SizedBox(height: 12),
          Text('购买失败', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.error)),
          const SizedBox(height: 6),
          Text(_errorMessage, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('关闭'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _backToSelectPeriod,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('重试'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- 底部按钮通用组件 --
  Widget _buildBottomButton({
    required ColorScheme colorScheme,
    required VoidCallback onPressed,
    required String label,
    bool isOutlined = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.15))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: isOutlined
              ? OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(label, style: const TextStyle(fontSize: 14)),
                )
              : FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
        ),
      ),
    );
  }
}

// -- 顶部标签芯片 --
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  const _HeaderChip({required this.icon, required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: colorScheme.onPrimary.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onPrimary.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onPrimary.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}
