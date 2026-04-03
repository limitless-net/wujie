import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

part 'generated/subscription_state.g.dart';

/// 订阅状态管理

/// 获取订阅信息
@riverpod
Future<SubscriptionModel> getSubscription(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.subscription.getSubscription();
}

/// 获取订阅链接
@riverpod
Future<String> getSubscribeUrl(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.subscription.getSubscribeUrl();
}
