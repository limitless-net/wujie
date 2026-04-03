import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

part 'generated/user_state.g.dart';

/// 用户状态管理

/// 获取用户信息
@riverpod
Future<UserModel> getUserInfo(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.user.getUserInfo();
}
