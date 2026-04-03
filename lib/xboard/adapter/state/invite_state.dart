import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

part 'generated/invite_state.g.dart';

/// 邀请状态管理

/// 获取邀请信息
@riverpod
Future<InviteInfoModel> getInviteInfo(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.invite.getInviteInfo();
}

/// 获取邀请码列表
@riverpod
Future<List<InviteCodeModel>> getInviteCodes(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.invite.getInviteCodes();
}

/// 获取佣金详情
@riverpod
Future<List<CommissionDetailModel>> getCommissionDetails(Ref ref, {int page = 1}) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.invite.getCommissionDetails(page: page);
}
