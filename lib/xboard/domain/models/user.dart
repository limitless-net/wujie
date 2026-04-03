import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/user.freezed.dart';
part 'generated/user.g.dart';

/// 领域层：用户模型（统一数据模型）
/// 
/// 这是业务核心模型，完全独立于任何 SDK 实现
/// 代表应用中"用户"的概念
@freezed
class DomainUser with _$DomainUser {
  const factory DomainUser({
    /// 用户邮箱（唯一标识）
    required String email,
    
    /// UUID（通用唯一标识符）
    required String uuid,
    
    /// 头像 URL
    required String avatarUrl,
    
    /// 套餐 ID（可能为空，新注册用户尚未购买套餐时为 null）
    int? planId,
    
    /// 总流量限制（字节）
    required int transferLimit,
    
    /// 已用上传流量（字节）
    required int uploadedBytes,
    
    /// 已用下载流量（字节）
    required int downloadedBytes,
    
    /// 账户余额（分）
    required int balanceInCents,
    
    /// 佣金余额（分）
    required int commissionBalanceInCents,
    
    /// 过期时间
    DateTime? expiredAt,
    
    /// 上次登录时间
    DateTime? lastLoginAt,
    
    /// 创建时间
    DateTime? createdAt,
    
    /// 是否被封禁
    @Default(false) bool banned,
    
    /// 到期提醒
    @Default(true) bool remindExpire,
    
    /// 流量提醒
    @Default(true) bool remindTraffic,
    
    /// 折扣率（0-1）
    double? discount,
    
    /// 佣金比例（0-1）
    double? commissionRate,
    
    /// Telegram ID
    String? telegramId,
    
    /// 元数据（存储 SDK 特有字段）
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainUser;

  const DomainUser._();

  factory DomainUser.fromJson(Map<String, dynamic> json) => 
    _$DomainUserFromJson(json);

  // ========== 业务逻辑（Getter） ==========

  /// 已用流量总计（字节）
  int get totalUsedBytes => uploadedBytes + downloadedBytes;

  /// 剩余流量（字节）
  int get remainingBytes {
    final remaining = transferLimit - totalUsedBytes;
    return remaining > 0 ? remaining : 0;
  }

  /// 流量使用百分比（0-100）
  double get usagePercentage {
    if (transferLimit == 0) return 0;
    return (totalUsedBytes / transferLimit * 100).clamp(0, 100);
  }

  /// 是否流量耗尽
  bool get isTrafficExhausted => remainingBytes == 0;

  /// 是否已过期
  bool get isExpired {
    if (expiredAt == null) return false;
    return DateTime.now().isAfter(expiredAt!);
  }

  /// 是否即将过期（7天内）
  bool get isExpiringSoon {
    if (expiredAt == null) return false;
    final daysRemaining = expiredAt!.difference(DateTime.now()).inDays;
    return daysRemaining >= 0 && daysRemaining <= 7;
  }

  /// 账户余额（元）
  double get balanceInYuan => balanceInCents / 100.0;

  /// 佣金余额（元）
  double get commissionBalanceInYuan => commissionBalanceInCents / 100.0;

  /// 格式化流量显示
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 剩余流量（格式化）
  String get remainingTraffic => formatBytes(remainingBytes);

  /// 已用流量（格式化）
  String get usedTraffic => formatBytes(totalUsedBytes);

  /// 总流量（格式化）
  String get totalTraffic => formatBytes(transferLimit);
}
