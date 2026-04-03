import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

part 'generated/notice_state.g.dart';

/// 公告状态管理

/// 获取公告列表
@riverpod
Future<List<NoticeModel>> getNotices(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.notice.getNotices();
}
