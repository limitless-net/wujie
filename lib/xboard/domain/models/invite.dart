import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/invite.freezed.dart';
part 'generated/invite.g.dart';

/// 领域层：邀请信息模型
@freezed
class DomainInvite with _$DomainInvite {
  const factory DomainInvite({
    /// 邀请码列表
    @Default([]) List<DomainInviteCode> codes,
    
    /// 邀请统计
    required InviteStats stats,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainInvite;

  const DomainInvite._();

  factory DomainInvite.fromJson(Map<String, dynamic> json) => 
    _$DomainInviteFromJson(json);
}

/// 邀请码模型
@freezed
class DomainInviteCode with _$DomainInviteCode {
  const factory DomainInviteCode({
    /// 邀请码
    required String code,
    
    /// 状态（0=未使用, 1=已使用）
    @Default(0) int status,
    
    /// 创建时间
    DateTime? createdAt,
    
    /// 使用时间
    DateTime? usedAt,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainInviteCode;

  const DomainInviteCode._();

  factory DomainInviteCode.fromJson(Map<String, dynamic> json) => 
    _$DomainInviteCodeFromJson(json);
}

/// DomainInviteCode 扩展方法
extension DomainInviteCodeX on DomainInviteCode {
  /// 是否已使用
  bool get isUsed => status == 1;

  /// 是否可用
  bool get isAvailable => status == 0;
}

/// 邀请统计模型
@freezed
class InviteStats with _$InviteStats {
  const factory InviteStats({
    /// 邀请人数
    @Default(0) int invitedCount,
    
    /// 佣金比例（0-1）
    @Default(0.0) double commissionRate,
    
    /// 待确认佣金（元）
    @Default(0.0) double pendingCommission,
    
    /// 可用佣金（元）
    @Default(0.0) double availableCommission,
    
    /// 总佣金（元）
    @Default(0.0) double totalCommission,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _InviteStats;

  const InviteStats._();

  factory InviteStats.fromJson(Map<String, dynamic> json) => 
    _$InviteStatsFromJson(json);
}

/// 佣金明细模型
@freezed
class DomainCommission with _$DomainCommission {
  const factory DomainCommission({
    /// ID
    required int id,
    
    /// 订单号
    required String tradeNo,
    
    /// 佣金金额（元）
    required double amount,
    
    /// 创建时间
    required DateTime createdAt,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainCommission;

  const DomainCommission._();

  factory DomainCommission.fromJson(Map<String, dynamic> json) => 
    _$DomainCommissionFromJson(json);
}
