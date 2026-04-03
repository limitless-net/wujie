import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

part 'generated/ticket_state.g.dart';

/// 工单状态管理

/// 获取工单列表
@riverpod
Future<List<TicketModel>> getTickets(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.ticket.getTickets();
}

/// 获取单个工单
@riverpod
Future<TicketDetailModel> getTicket(Ref ref, int id) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.ticket.getTicket(id);
}
