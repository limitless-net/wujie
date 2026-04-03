import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show XBoardSDK, CouponModel;
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import '../widgets/payment_waiting_overlay.dart';
import '../widgets/payment_method_selector_dialog.dart';
import '../widgets/plan_header_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/coupon_input_section.dart';
import '../widgets/price_summary_card.dart';
import '../models/payment_step.dart';
import '../utils/price_calculator.dart';

// 初始化文件级日志器
final _logger = FileLogger('plan_purchase_page.dart');

/// 套餐购买页面
class PlanPurchasePage extends ConsumerStatefulWidget {
  final DomainPlan plan;
  final bool embedded; // 是否为嵌入模式（桌面端页面内切换时使用）
  final VoidCallback? onBack; // 返回回调

  const PlanPurchasePage({
    super.key,
    required this.plan,
    this.embedded = false,
    this.onBack,
  });

  @override
  ConsumerState<PlanPurchasePage> createState() => _PlanPurchasePageState();
}

class _PlanPurchasePageState extends ConsumerState<PlanPurchasePage> {
  // 周期选择
  String? _selectedPeriod;

  // 优惠券相关
  final _couponController = TextEditingController();
  bool _isCouponValidating = false;
  bool? _isCouponValid;
  String? _couponErrorMessage;
  String? _couponCode;
  int? _couponType;
  int? _couponValue;
  double? _discountAmount;
  double? _finalPrice;

  // 用户余额
  double? _userBalance;
  bool _isLoadingBalance = false;

  @override
  void initState() {
    super.initState();
    // 确保 PaymentProvider 被初始化，以便开始加载支付方式
    ref.read(xboardPaymentProvider);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final periods = _getAvailablePeriods(context);
      if (periods.isNotEmpty && _selectedPeriod == null) {  
        setState(() {
          _selectedPeriod = periods.first['period'];
        });
      }
      _loadUserBalance();
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  // ========== 数据加载 ==========

  Future<void> _loadUserBalance() async {
    setState(() => _isLoadingBalance = true);
    try {
      // 使用 xboardUserProvider 获取用户信息
      final userInfo = ref.read(xboardUserProvider).userInfo;
      
      if (mounted) {
        setState(() => _userBalance = userInfo?.balanceInYuan);
      }
    } catch (e) {
      _logger.debug('[购买] 加载用户余额失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  List<Map<String, dynamic>> _getAvailablePeriods(BuildContext context) {
    final List<Map<String, dynamic>> periods = [];
    final plan = widget.plan;
    final l10n = AppLocalizations.of(context);

    if (plan.monthlyPrice != null) {
      periods.add({
        'period': 'month_price',
        'label': l10n.xboardMonthlyPayment,
        'price': plan.monthlyPrice!,
        'description': l10n.xboardMonthlyRenewal,
      });
    }
    if (plan.quarterlyPrice != null) {
      periods.add({
        'period': 'quarter_price',
        'label': l10n.xboardQuarterlyPayment,
        'price': plan.quarterlyPrice!,
        'description': l10n.xboardThreeMonthCycle,
      });
    }
    if (plan.halfYearlyPrice != null) {
      periods.add({
        'period': 'half_year_price',
        'label': l10n.xboardHalfYearlyPayment,
        'price': plan.halfYearlyPrice!,
        'description': l10n.xboardSixMonthCycle,
      });
    }
    if (plan.yearlyPrice != null) {
      periods.add({
        'period': 'year_price',
        'label': l10n.xboardYearlyPayment,
        'price': plan.yearlyPrice!,
        'description': l10n.xboardTwelveMonthCycle,
      });
    }
    if (plan.twoYearPrice != null) {
      periods.add({
        'period': 'two_year_price',
        'label': l10n.xboardTwoYearPayment,
        'price': plan.twoYearPrice!,
        'description': l10n.xboardTwentyFourMonthCycle,
      });
    }
    if (plan.threeYearPrice != null) {
      periods.add({
        'period': 'three_year_price',
        'label': l10n.xboardThreeYearPayment,
        'price': plan.threeYearPrice!,
        'description': l10n.xboardThirtySixMonthCycle,
      });
    }
    if (plan.onetimePrice != null) {
      periods.add({
        'period': 'onetime_price',
        'label': l10n.xboardOneTimePayment,
        'price': plan.onetimePrice!,
        'description': l10n.xboardBuyoutPlan,
      });
    }

    return periods;
  }

  double _getCurrentPrice() {
    if (_selectedPeriod == null) return 0.0;
    final periods = _getAvailablePeriods(context);
    final selectedPeriod = periods.firstWhere(
      (period) => period['period'] == _selectedPeriod,
      orElse: () => {},
    );
    return selectedPeriod['price']?.toDouble() ?? 0.0;
  }

  // ========== 优惠券验证 ==========

  Future<void> _validateCoupon() async {
    if (_couponController.text.trim().isEmpty) {
      _clearCoupon();
      return;
    }

    setState(() {
      _isCouponValidating = true;
      _isCouponValid = null;
      _couponErrorMessage = null;
    });

    try {
      final couponCode = _couponController.text.trim();
      // TODO: 将来添加到 PaymentRepository，目前保留使用 SDK
      final couponData = await XBoardSDK.instance.order.checkCoupon(
        _couponController.text.trim(),
        widget.plan.id,
      );

      if (couponData != null && mounted) {
        _applyCoupon(couponCode, couponData);
      } else if (mounted) {
        _setCouponInvalid();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCouponValid = false;
          _couponErrorMessage = '${AppLocalizations.of(context).xboardValidationFailed}: ${e.toString()}';
          _clearCouponData();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCouponValidating = false);
      }
    }
  }

  void _applyCoupon(String code, CouponModel couponData) {
    final currentPrice = _getCurrentPrice();
    final discountAmount = PriceCalculator.calculateDiscountAmount(
      currentPrice,
      couponData.type,
      couponData.value,
    );
    final finalPrice = currentPrice - discountAmount;

    setState(() {
      _isCouponValid = true;
      _couponCode = code;
      _couponType = couponData.type;
      _couponValue = couponData.value;
      _discountAmount = discountAmount;
      _finalPrice = finalPrice > 0 ? finalPrice : 0;
      _couponErrorMessage = null;
    });
  }

  void _setCouponInvalid() {
    setState(() {
      _isCouponValid = false;
      _couponErrorMessage = AppLocalizations.of(context).xboardInvalidOrExpiredCoupon;
      _clearCouponData();
    });
  }

  void _clearCoupon() {
    if (mounted) {
      setState(() {
        _isCouponValid = null;
        _couponErrorMessage = null;
        _clearCouponData();
      });
    }
  }

  void _clearCouponData() {
    _discountAmount = null;
    _finalPrice = null;
    _couponCode = null;
    _couponType = null;
    _couponValue = null;
  }

  void _recalculateDiscount() {
    if (_couponType == null || _couponValue == null) return;

    final currentPrice = _getCurrentPrice();
    final discountAmount = PriceCalculator.calculateDiscountAmount(
      currentPrice,
      _couponType,
      _couponValue,
    );

    setState(() {
      _discountAmount = discountAmount;
      _finalPrice = PriceCalculator.calculateFinalPrice(
        currentPrice,
        _couponType,
        _couponValue,
      );
    });
  }

  // ========== 购买流程 ==========

  Future<void> _proceedToPurchase() async {
    if (_selectedPeriod == null) {
      XBoardNotification.showError(AppLocalizations.of(context).xboardPleaseSelectPaymentPeriod);
      return;
    }

    try {
      String? tradeNo;
      _logger.debug('[购买] 开始购买流程，套餐ID: ${widget.plan.id}, 周期: $_selectedPeriod');

      // 显示支付等待页面
      if (mounted) {
        _showPaymentWaiting(null);
        PaymentWaitingManager.updateStep(PaymentStep.cancelingOrders);
      }

      // 创建订单
      _logger.debug('[购买] 创建订单');
      PaymentWaitingManager.updateStep(PaymentStep.createOrder);
      
      final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
      tradeNo = await paymentNotifier.createOrder(
        planId: widget.plan.id,
        period: _selectedPeriod!,
        couponCode: _couponCode,
      );

      if (tradeNo == null) {
        final errorMessage = ref.read(userUIStateProvider).errorMessage;
        throw Exception('${AppLocalizations.of(context).xboardOrderCreationFailed}: $errorMessage');
      }

      _logger.debug('[购买] 订单创建成功: $tradeNo');
      PaymentWaitingManager.updateTradeNo(tradeNo);

      // 计算实付金额
      final displayFinalPrice = _finalPrice ?? _getCurrentPrice();
      final balanceToUse = _userBalance != null && _userBalance! > 0
          ? (_userBalance! > displayFinalPrice ? displayFinalPrice : _userBalance!)
          : 0.0;
      final actualPayAmount = displayFinalPrice - balanceToUse;

      _logger.debug('[购买] 实付金额: $actualPayAmount (优惠后价格: $displayFinalPrice, 余额抵扣: $balanceToUse)');

      // 使用 xboardAvailablePaymentMethodsProvider 获取支付方式
      final paymentMethods = ref.read(xboardAvailablePaymentMethodsProvider);
      
      _logger.info('[购买] 获取到的支付方式数量: ${paymentMethods.length}');
      if (paymentMethods.isNotEmpty) {
        _logger.info('[购买] 支付方式列表:');
        for (var method in paymentMethods) {
          _logger.info('  - ${method.name} (id: ${method.id})');
        }
      } else {
        _logger.error('[购买] ⚠️ 支付方式列表为空！');
      }
      
      if (paymentMethods.isEmpty) {
        throw Exception('暂无可用的支付方式');
      }
      
      DomainPaymentMethod? selectedMethod;
      
      // 如果实付金额为0（余额完全抵扣），自动选择第一个支付方式，跳过用户选择
      if (actualPayAmount <= 0) {
        _logger.debug('[购买] 实付金额为0，自动选择第一个支付方式');
        selectedMethod = paymentMethods.first;
        // 显示支付等待页面
        if (mounted) {
          _showPaymentWaiting(tradeNo);
        }
      } else {
        // 需要实际支付，让用户选择支付方式
        selectedMethod = await _selectPaymentMethod(paymentMethods, tradeNo);
        if (selectedMethod == null) return;
      }

      // 提交支付
      await _submitPayment(tradeNo, selectedMethod);
    } catch (e) {
      _logger.error('购买流程出错: $e');
        if (mounted) {
        PaymentWaitingManager.hide();
        XBoardNotification.showError('操作失败: ${e.toString()}');
      }
    }
  }

  void _showPaymentWaiting(String? tradeNo) {
          PaymentWaitingManager.show(
            context,
      onClose: () => Navigator.of(context).pop(),
      onPaymentSuccess: _handlePaymentSuccess,
      tradeNo: tradeNo,
    );
  }

  void _handlePaymentSuccess() {
    _logger.info('[支付成功] 处理支付成功回调');
    try {
      final userProvider = ref.read(xboardUserProvider.notifier);
      userProvider.refreshSubscriptionInfoAfterPayment();
    } catch (e) {
      _logger.info('[支付成功] 刷新订阅信息失败: $e');
    }

    if (mounted) {
      XBoardNotification.showSuccess(AppLocalizations.of(context).xboardPaymentSuccess);
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        try {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } catch (e) {
          _logger.info('[支付成功] 导航失败: $e');
        }
      }
    });
  }

  Future<DomainPaymentMethod?> _selectPaymentMethod(
    List<DomainPaymentMethod> methods,
    String tradeNo,
  ) async {
    if (methods.length == 1) {
      // 单一支付方式，直接显示等待页面并返回
      if (mounted) {
        _showPaymentWaiting(tradeNo);
      }
      return methods.first;
    }

    PaymentWaitingManager.hide();
    if (!mounted) return null;

    final selected = await PaymentMethodSelectorDialog.show(
      context,
      paymentMethods: methods,
    );

    if (selected == null) {
      _logger.debug('[支付] 用户取消选择支付方式');
      return null;
    }

    if (mounted) {
      _showPaymentWaiting(tradeNo);
    }

    return selected;
  }

  Future<void> _submitPayment(String tradeNo, DomainPaymentMethod method) async {
    _logger.debug('[支付] 提交支付: $tradeNo, 方式: ${method.id}');
      PaymentWaitingManager.updateStep(PaymentStep.loadingPayment);
      PaymentWaitingManager.updateStep(PaymentStep.verifyPayment);

    final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
      final paymentResult = await paymentNotifier.submitPayment(
        tradeNo: tradeNo,
      method: method.id.toString(),
      );
      
    if (paymentResult == null) {
      throw Exception('支付失败: 支付请求返回空结果');
    }
      
    if (!mounted) return;
        
    final paymentType = paymentResult['type'] as int? ?? 0;
    final paymentData = paymentResult['data'];
        
    _logger.debug('[支付] type=$paymentType, data=$paymentData (${paymentData.runtimeType})');
        
    // type: -1 余额支付成功（data 是 bool）
    // type: 0 跳转支付（data 是 String）
    // type: 1 二维码支付（data 是 String）
    if (paymentType == -1) {
      // 免费订单/余额支付，data 是 bool
      if (paymentData == true) {
        await _handleBalancePaymentSuccess();
      } else {
        throw Exception('支付失败: 余额支付未成功 (data=$paymentData)');
      }
    } else if (paymentData != null && paymentData is String && paymentData.isNotEmpty) {
      // 付费订单，data 是支付URL（String）
      PaymentWaitingManager.updateStep(PaymentStep.waitingPayment);
      await _launchPaymentUrl(paymentData, tradeNo);
    } else {
      throw Exception('支付失败: 未获取到有效的支付数据 (type=$paymentType, data=$paymentData)');
    }
  }

  Future<void> _handleBalancePaymentSuccess() async {
    _logger.debug('[支付] 余额支付成功');
          PaymentWaitingManager.hide();
          
          try {
            final userProvider = ref.read(xboardUserProvider.notifier);
            userProvider.refreshSubscriptionInfoAfterPayment();
          } catch (e) {
      _logger.debug('[余额支付] 刷新订阅信息失败: $e');
          }
          
          if (mounted) {
            XBoardNotification.showSuccess(AppLocalizations.of(context).xboardPaymentSuccess);
            
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                try {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } catch (e) {
            _logger.debug('[余额支付] 导航失败: $e');
                }
              }
            });
    }
  }

  Future<void> _launchPaymentUrl(String url, String tradeNo) async {
    try {
      if (!mounted) return;

        await Clipboard.setData(ClipboardData(text: url));
        final uri = Uri.parse(url);

        if (!await canLaunchUrl(uri)) {
          throw Exception('无法打开支付链接');
        }

        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          throw Exception('无法启动外部浏览器');
      }

      _logger.debug('[支付] 支付页面已在浏览器中打开: $tradeNo');
    } catch (e) {
      if (mounted) {
        PaymentWaitingManager.hide();
        XBoardNotification.showError('打开支付页面失败: ${e.toString()}');
      }
    }
  }

  // ========== UI 构建 ==========

  @override
  Widget build(BuildContext context) {
    final periods = _getAvailablePeriods(context);
    final currentPrice = _getCurrentPrice();
    // 用于判断平台类型
    final isPlatformDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // 套餐信息卡片
              PlanHeaderCard(plan: widget.plan),
              const SizedBox(height: 20),

              // 周期选择器
              PeriodSelector(
                periods: periods,
                selectedPeriod: _selectedPeriod,
                onPeriodSelected: (period) {
                          setState(() {
                    _selectedPeriod = period;
                    if (_couponCode != null) {
                      _recalculateDiscount();
                    }
                  });
                },
                couponType: _couponType,
                couponValue: _couponValue,
              ),
              const SizedBox(height: 20),

              // 优惠券输入
              CouponInputSection(
                controller: _couponController,
                isValidating: _isCouponValidating,
                isValid: _isCouponValid,
                errorMessage: _couponErrorMessage,
                discountAmount: _discountAmount,
                onValidate: _validateCoupon,
                onChanged: _clearCoupon,
              ),
              const SizedBox(height: 20),

              // 价格汇总
              if (_selectedPeriod != null)
                PriceSummaryCard(
                  originalPrice: currentPrice,
                  finalPrice: _finalPrice,
                  discountAmount: _discountAmount,
                  userBalance: _userBalance,
                ),
              const SizedBox(height: 20),

              // 确认购买按钮
            SizedBox(
              width: double.infinity,
                height: 54,
              child: Consumer(
                builder: (context, ref, child) {
                  final paymentState = ref.watch(userUIStateProvider);
                  return ElevatedButton(
                      onPressed: paymentState.isLoading ? null : _proceedToPurchase,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                        elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: paymentState.isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                                const SizedBox(width: 12),
                                Text(
                                  AppLocalizations.of(context).xboardProcessing,
                                  style: const TextStyle(fontSize: 16),
                                ),
                            ],
                          )
                        : Text(
                            AppLocalizations.of(context).xboardConfirmPurchase,
                            style: const TextStyle(
                                fontSize: 17,
                              fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                            ),
                          ),
                  );
                },
              ),
            ),
              const SizedBox(height: 16),
          ],
          ),
        ),
      ),
    );

    // 桌面端嵌入模式：只返回内容（外层已有 Scaffold）
    if (widget.embedded) {
      return content;
    }

    // 移动端全屏或独立页面：带 AppBar 的 Scaffold
    return Scaffold(
      appBar: isPlatformDesktop ? null : AppBar(
        title: Text(AppLocalizations.of(context).xboardPurchaseSubscription),
      ),
      body: content,
    );
  }
} 

