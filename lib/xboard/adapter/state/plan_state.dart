import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

part 'generated/plan_state.g.dart';

/// 套餐状态管理

/// 获取套餐列表
@riverpod
Future<List<PlanModel>> getPlans(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.plan.getPlans();
}

/// 获取单个套餐
@riverpod
Future<PlanModel?> getPlan(Ref ref, int id) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.plan.getPlan(id);
}
