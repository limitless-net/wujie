import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/models/models.dart';

/// 支付仓储接口
abstract class PaymentRepository {
  /// 获取支付方式列表
  Future<Result<List<DomainPaymentMethod>>> getPaymentMethods();

  /// 提交支付
  /// 
  /// 返回支付结果：
  /// - type: -1=余额支付成功, 0=跳转支付, 1=二维码支付
  /// - data: 支付 URL 或其他数据
  Future<Result<PaymentResult>> submitPayment({
    required String tradeNo,
    required int methodId,
  });

  /// 查询支付状态
  /// 
  /// 返回订单状态码
  Future<Result<int>> checkPaymentStatus(String tradeNo);
}

/// 支付结果
class PaymentResult {
  /// 支付类型
  /// -1: 余额支付成功
  /// 0: 跳转支付
  /// 1: 二维码支付
  final int type;

  /// 支付数据
  /// - type = -1: bool（余额支付是否成功）
  /// - type = 0: String（跳转支付 URL）
  /// - type = 1: String（二维码支付数据）
  final dynamic data;

  const PaymentResult({
    required this.type,
    this.data,
  });

  /// 是否余额支付成功
  bool get isBalancePaid => type == -1 && data == true;

  /// 是否跳转支付
  bool get isRedirectPayment => type == 0;

  /// 是否二维码支付
  bool get isQRCodePayment => type == 1;
  
  /// 获取支付 URL（用于跳转支付和二维码支付）
  String? get paymentUrl => data is String ? data as String : null;
}
