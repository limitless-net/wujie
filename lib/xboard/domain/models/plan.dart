import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/plan.freezed.dart';
part 'generated/plan.g.dart';

/// 领域层：套餐模型
/// 
/// 代表应用中"套餐/订阅计划"的概念
@freezed
class DomainPlan with _$DomainPlan {
  const factory DomainPlan({
    /// 套餐 ID
    required int id,
    
    /// 套餐名称
    required String name,
    
    /// 分组 ID
    required int groupId,
    
    /// 流量配额（字节）
    required int transferQuota,
    
    /// 套餐说明/描述
    String? description,
    
    /// 标签列表
    @Default([]) List<String> tags,
    
    /// 速度限制（Mbps）
    int? speedLimit,
    
    /// 设备数量限制
    int? deviceLimit,
    
    /// 是否显示
    @Default(true) bool isVisible,
    
    /// 是否可续费
    @Default(true) bool renewable,
    
    /// 排序值
    int? sort,
    
    // ========== 价格信息（单位：元） ==========
    
    /// 一次性购买价格
    double? onetimePrice,
    
    /// 月付价格
    double? monthlyPrice,
    
    /// 季付价格
    double? quarterlyPrice,
    
    /// 半年付价格
    double? halfYearlyPrice,
    
    /// 年付价格
    double? yearlyPrice,
    
    /// 两年付价格
    double? twoYearPrice,
    
    /// 三年付价格
    double? threeYearPrice,
    
    /// 重置流量价格
    double? resetPrice,
    
    /// 创建时间
    DateTime? createdAt,
    
    /// 更新时间
    DateTime? updatedAt,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainPlan;

  const DomainPlan._();

  factory DomainPlan.fromJson(Map<String, dynamic> json) => 
    _$DomainPlanFromJson(json);

  // ========== 业务逻辑 ==========

  /// 是否有任何价格
  bool get hasPrice {
    return [
      onetimePrice,
      monthlyPrice,
      quarterlyPrice,
      halfYearlyPrice,
      yearlyPrice,
      twoYearPrice,
      threeYearPrice,
    ].any((price) => price != null && price > 0);
  }

  /// 是否可购买
  bool get isPurchasable => isVisible && hasPrice;

  /// 获取最低价格
  double? get lowestPrice {
    final prices = [
      onetimePrice,
      monthlyPrice,
      quarterlyPrice,
      halfYearlyPrice,
      yearlyPrice,
      twoYearPrice,
      threeYearPrice,
    ].where((p) => p != null && p > 0).toList();

    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a! < b! ? a : b);
  }

  /// 获取所有可用的支付周期
  List<PlanPeriod> get availablePeriods {
    final periods = <PlanPeriod>[];
    
    if (onetimePrice != null && onetimePrice! > 0) {
      periods.add(PlanPeriod.onetime);
    }
    if (monthlyPrice != null && monthlyPrice! > 0) {
      periods.add(PlanPeriod.monthly);
    }
    if (quarterlyPrice != null && quarterlyPrice! > 0) {
      periods.add(PlanPeriod.quarterly);
    }
    if (halfYearlyPrice != null && halfYearlyPrice! > 0) {
      periods.add(PlanPeriod.halfYearly);
    }
    if (yearlyPrice != null && yearlyPrice! > 0) {
      periods.add(PlanPeriod.yearly);
    }
    if (twoYearPrice != null && twoYearPrice! > 0) {
      periods.add(PlanPeriod.twoYear);
    }
    if (threeYearPrice != null && threeYearPrice! > 0) {
      periods.add(PlanPeriod.threeYear);
    }
    
    return periods;
  }

  /// 根据周期获取价格
  double? getPriceByPeriod(PlanPeriod period) {
    switch (period) {
      case PlanPeriod.onetime:
        return onetimePrice;
      case PlanPeriod.monthly:
        return monthlyPrice;
      case PlanPeriod.quarterly:
        return quarterlyPrice;
      case PlanPeriod.halfYearly:
        return halfYearlyPrice;
      case PlanPeriod.yearly:
        return yearlyPrice;
      case PlanPeriod.twoYear:
        return twoYearPrice;
      case PlanPeriod.threeYear:
        return threeYearPrice;
      case PlanPeriod.reset:
        return resetPrice;
    }
  }

  /// 格式化流量显示
  String get formattedTraffic {
    final gb = transferQuota / (1024 * 1024 * 1024);
    if (gb < 1024) {
      return '${gb.toStringAsFixed(0)} GB';
    } else {
      final tb = gb / 1024;
      return '${tb.toStringAsFixed(2)} TB';
    }
  }
}

/// 套餐周期枚举
enum PlanPeriod {
  onetime('onetime', '一次性'),
  monthly('month', '月付'),
  quarterly('quarter', '季付'),
  halfYearly('half_year', '半年付'),
  yearly('year', '年付'),
  twoYear('two_year', '两年付'),
  threeYear('three_year', '三年付'),
  reset('reset', '重置流量');

  const PlanPeriod(this.value, this.label);
  
  final String value;
  final String label;

  /// 从字符串值创建
  static PlanPeriod fromValue(String value) {
    return PlanPeriod.values.firstWhere(
      (p) => p.value == value,
      orElse: () => PlanPeriod.monthly,
    );
  }
}
