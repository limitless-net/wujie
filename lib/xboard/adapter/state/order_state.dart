import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

part 'generated/order_state.g.dart';

/// 订单状态管理

/// 获取订单列表
@riverpod
Future<List<OrderModel>> getOrders(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.order.getOrders();
}

/// 获取单个订单
@riverpod
Future<OrderModel?> getOrder(Ref ref, String tradeNo) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.order.getOrder(tradeNo);
}

/// 获取订单支付方式
@riverpod
Future<List<PaymentMethodModel>> getOrderPaymentMethods(Ref ref, String tradeNo) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.order.getPaymentMethods(tradeNo);
}

/// 检查优惠券
@riverpod
Future<CouponModel?> checkCoupon(Ref ref, {required String code, required int planId}) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.order.checkCoupon(code, planId);
}
