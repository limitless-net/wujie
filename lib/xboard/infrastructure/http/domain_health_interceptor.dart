import 'package:dio/dio.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('domain_health_interceptor');

/// 域名连接健康监控拦截器
///
/// 监控 API 请求的连接健康状态。当连续 N 次请求出现连接级错误时，
/// 触发回调进行域名重新竞速，自动切换到可用域名。
///
/// 只监控连接级错误（超时、TLS 失败、连接拒绝等），
/// 忽略业务级错误（HTTP 4xx/5xx —— 说明连接本身是通的）。
class DomainHealthInterceptor extends Interceptor {
  final int failureThreshold;
  final Future<void> Function() onDomainUnhealthy;

  int _consecutiveFailures = 0;
  bool _isRecovering = false;

  DomainHealthInterceptor({
    this.failureThreshold = 3,
    required this.onDomainUnhealthy,
  });

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 收到任何 HTTP 响应（包括 4xx/5xx）都说明连接是通的
    if (_consecutiveFailures > 0) {
      _consecutiveFailures = 0;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isConnectionError(err)) {
      _consecutiveFailures++;
      _logger.warning(
        '[HealthCheck] 连接失败 ($_consecutiveFailures/$failureThreshold): '
        '${err.type.name} - ${err.message ?? err.error}',
      );

      if (_consecutiveFailures >= failureThreshold && !_isRecovering) {
        _isRecovering = true;
        _logger.warning(
          '[HealthCheck] ⚠️ 连续 $_consecutiveFailures 次连接失败，触发域名重新竞速',
        );

        // 异步触发恢复，不阻塞当前错误传递
        onDomainUnhealthy().then((_) {
          _consecutiveFailures = 0;
          _isRecovering = false;
          _logger.info('[HealthCheck] ✅ 域名恢复完成');
        }).catchError((e) {
          _isRecovering = false;
          _logger.error('[HealthCheck] ❌ 域名恢复失败: $e');
        });
      }
    }

    handler.next(err);
  }

  /// 判断是否是连接级错误（非业务错误）
  bool _isConnectionError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // unknown 包含 TLS 握手失败、socket 异常等连接级错误
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }
}
