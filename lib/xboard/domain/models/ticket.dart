import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/ticket.freezed.dart';
part 'generated/ticket.g.dart';

/// 领域层：工单模型
@freezed
class DomainTicket with _$DomainTicket {
  const factory DomainTicket({
    /// 工单 ID
    required int id,
    
    /// 标题
    required String subject,
    
    /// 优先级（低=0, 中=1, 高=2）
    @Default(1) int priority,
    
    /// 状态
    required TicketStatus status,
    
    /// 消息列表
    @Default([]) List<TicketMessage> messages,
    
    /// 创建时间
    required DateTime createdAt,
    
    /// 更新时间
    DateTime? updatedAt,
    
    /// 关闭时间
    DateTime? closedAt,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainTicket;

  const DomainTicket._();

  factory DomainTicket.fromJson(Map<String, dynamic> json) => 
    _$DomainTicketFromJson(json);
}

/// DomainTicket 扩展方法
extension DomainTicketX on DomainTicket {
  /// 优先级标签
  String get priorityLabel {
    switch (priority) {
      case 0:
        return '低';
      case 1:
        return '中';
      case 2:
        return '高';
      default:
        return '未知';
    }
  }

  /// 是否已关闭
  bool get isClosed => status == TicketStatus.closed;

  /// 是否待回复
  bool get isPendingReply => status == TicketStatus.pending;

  /// 未读消息数
  int get unreadCount {
    return messages.where((m) => !m.isRead && !m.isFromUser).length;
  }

  /// 最后一条消息
  TicketMessage? get lastMessage {
    if (messages.isEmpty) return null;
    return messages.last;
  }
}

/// 工单状态枚举
enum TicketStatus {
  /// 待处理
  pending(0, '待处理'),
  
  /// 已回复
  replied(1, '已回复'),
  
  /// 已关闭
  closed(2, '已关闭');

  const TicketStatus(this.code, this.label);
  
  final int code;
  final String label;

  static TicketStatus fromCode(int code) {
    return TicketStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => TicketStatus.pending,
    );
  }
}

/// 工单消息模型
@freezed
class TicketMessage with _$TicketMessage {
  const factory TicketMessage({
    /// 消息 ID
    required int id,
    
    /// 消息内容
    required String content,
    
    /// 是否来自用户
    @Default(true) bool isFromUser,
    
    /// 是否已读
    @Default(false) bool isRead,
    
    /// 附件列表
    @Default([]) List<String> attachments,
    
    /// 创建时间
    required DateTime createdAt,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _TicketMessage;

  const TicketMessage._();

  factory TicketMessage.fromJson(Map<String, dynamic> json) => 
    _$TicketMessageFromJson(json);
}

/// TicketMessage 扩展方法
extension TicketMessageX on TicketMessage {
  /// 是否有附件
  bool get hasAttachments => attachments.isNotEmpty;
}
