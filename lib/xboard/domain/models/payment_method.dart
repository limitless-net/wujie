import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/payment_method.freezed.dart';
part 'generated/payment_method.g.dart';

/// 领域层：支付方式模型
@freezed
class DomainPaymentMethod with _$DomainPaymentMethod {
  const factory DomainPaymentMethod({
    /// 支付方式 ID
    required int id,
    
    /// 支付方式名称
    required String name,
    
    /// 图标 URL
    String? iconUrl,
    
    /// 手续费百分比（0-100）
    @Default(0.0) double feePercentage,
    
    /// 是否可用
    @Default(true) bool isAvailable,
    
    /// 描述
    String? description,
    
    /// 最小金额（元）
    double? minAmount,
    
    /// 最大金额（元）
    double? maxAmount,
    
    /// 配置信息
    @Default({}) Map<String, dynamic> config,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainPaymentMethod;

  const DomainPaymentMethod._();

  factory DomainPaymentMethod.fromJson(Map<String, dynamic> json) => 
    _$DomainPaymentMethodFromJson(json);
}

/// DomainPaymentMethod 扩展方法
extension DomainPaymentMethodX on DomainPaymentMethod {
  // ========== 业务逻辑 ==========

  /// 是否有手续费
  bool get hasFee => feePercentage > 0;

  /// 计算实际支付金额（含手续费）
  double calculateTotalAmount(double baseAmount) {
    return baseAmount * (1 + feePercentage / 100);
  }

  /// 计算手续费
  double calculateFee(double baseAmount) {
    return baseAmount * (feePercentage / 100);
  }

  /// 是否在金额范围内
  bool isAmountValid(double amount) {
    if (minAmount != null && amount < minAmount!) return false;
    if (maxAmount != null && amount > maxAmount!) return false;
    return true;
  }
}
