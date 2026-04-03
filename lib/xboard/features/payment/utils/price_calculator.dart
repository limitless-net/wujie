/// 价格计算工具类
class PriceCalculator {
  /// 根据优惠券类型和值计算折扣金额
  /// 
  /// [originalPrice] 原价
  /// [couponType] 优惠券类型：1-金额折扣，2-百分比折扣
  /// [couponValue] 优惠券值（金额类型为分，百分比类型为百分比）
  static double calculateDiscountAmount(
    double originalPrice,
    int? couponType,
    int? couponValue,
  ) {
    if (couponType == null || couponValue == null) {
      return 0.0;
    }

    double discountAmount = 0.0;
    
    if (couponType == 1) {
      // 金额折扣：value 是分，需要转换为元
      discountAmount = couponValue / 100.0;
    } else if (couponType == 2) {
      // 百分比折扣：value 是百分比 (如 20 表示 20%)
      discountAmount = originalPrice * couponValue / 100.0;
    }

    // 确保折扣不超过原价
    if (discountAmount > originalPrice) {
      discountAmount = originalPrice;
    }

    return discountAmount;
  }

  /// 计算折扣后的最终价格
  static double calculateFinalPrice(
    double originalPrice,
    int? couponType,
    int? couponValue,
  ) {
    final discountAmount = calculateDiscountAmount(
      originalPrice,
      couponType,
      couponValue,
    );
    
    final finalPrice = originalPrice - discountAmount;
    return finalPrice > 0 ? finalPrice : 0;
  }

  /// 格式化价格显示
  static String formatPrice(double? price) {
    if (price == null) return '-';
    return '¥${price.toStringAsFixed(2)}';
  }

  /// 格式化流量显示
  static String formatTraffic(double transferEnable) {
    if (transferEnable >= 1024) {
      return '${(transferEnable / 1024).toStringAsFixed(1)}TB';
    }
    return '${transferEnable.toStringAsFixed(0)}GB';
  }
}

