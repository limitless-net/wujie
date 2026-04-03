import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/models/models.dart';

/// 工单仓储接口
abstract class TicketRepository {
  /// 获取工单列表
  Future<Result<List<DomainTicket>>> getTickets();

  /// 获取工单详情
  Future<Result<DomainTicket>> getTicketDetail(int ticketId);

  /// 创建工单
  Future<Result<DomainTicket>> createTicket({
    required String subject,
    required String message,
    required int priority,
  });

  /// 回复工单
  Future<Result<void>> replyTicket({
    required int ticketId,
    required String message,
  });

  /// 关闭工单
  Future<Result<void>> closeTicket(int ticketId);
}
