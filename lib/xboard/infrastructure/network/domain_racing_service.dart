/// 域名竞速服务
///
/// 实现多个域名并发测试，选择响应最快的域名
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/infrastructure/http/user_agent_config.dart';
import 'package:socks5_proxy/socks_client.dart';

// 初始化文件级日志器
final _logger = FileLogger('domain_racing_service.dart');

/// 域名竞速服务
class DomainRacingService {
  static const Duration _connectionTimeout = Duration(seconds: 5);
  static const Duration _responseTimeout = Duration(seconds: 8);
  
  /// 设置证书路径（由配置加载器调用）
  static void setCertificatePath(String path) {
    _configuredCertPath = path;
    // 清除缓存的 SecurityContext，下次使用时会重新加载
    _securityContext = null;
  }

  // 缓存加载的证书
  static SecurityContext? _securityContext;
  static String? _configuredCertPath;

  /// 获取配置了CA证书的SecurityContext
  static Future<SecurityContext> _getSecurityContext() async {
    if (_securityContext != null) {
      return _securityContext!;
    }

    try {
      // 只使用配置文件中的证书路径
      if (_configuredCertPath == null || _configuredCertPath!.isEmpty) {
        _logger.info('[域名竞速] 未配置CA证书路径，跳过证书加载');
        return SecurityContext.defaultContext;
      }

      _logger.info('[域名竞速] 加载自定义CA证书: $_configuredCertPath');

      // 加载证书文件
      final ByteData certData = await rootBundle.load(_configuredCertPath!);
      final Uint8List certBytes = certData.buffer.asUint8List();

      // 创建SecurityContext并添加证书
      final context = SecurityContext();
      context.setTrustedCertificatesBytes(certBytes);

      _securityContext = context;
      _logger.info('[域名竞速] CA证书加载成功');

      return _securityContext!;
    } catch (e) {
      _logger.error('[域名竞速] CA证书加载失败', e);
      // 回退到默认SecurityContext
      _securityContext = SecurityContext.defaultContext;
      return _securityContext!;
    }
  }

  /// 并发竞速选择最快域名
  ///
  /// [domains] 要测试的域名列表
  /// [testPath] 用于测试的路径，默认为空（只测试连通性）
  /// [forceHttpsResult] 是否强制返回HTTPS格式的结果（用于SDK初始化）
  /// [proxyUrls] 可选的代理地址列表，每个域名会测试直连+所有代理
  ///
  /// 返回最快响应的结果（包含域名和是否使用代理），如果所有域名都失败则返回null
  static Future<DomainRacingResult?> raceSelectFastestDomain(
    List<String> domains, {
    String testPath = '',
    bool forceHttpsResult = false,
    List<String>? proxyUrls,
  }) async {
    if (domains.isEmpty) return null;
    
    final proxies = proxyUrls ?? [];
    final testCount = domains.length * (1 + proxies.length);
    
    _logger.info('[域名竞速] 开始竞速测试 ${domains.length} 个域名${proxies.isNotEmpty ? '（每个测试直连+${proxies.length}个代理）' : ''}，共 $testCount 个测试');

    // 创建并发测试任务
    final List<Future<DomainTestResult>> futures = [];
    final List<CancelToken> cancelTokens = [];

    int taskIndex = 0;
    for (int i = 0; i < domains.length; i++) {
      final domain = domains[i];
      
      // 测试直连
      final directToken = CancelToken();
      cancelTokens.add(directToken);
      futures.add(_testSingleDomain(domain, testPath, directToken, taskIndex++, useProxy: false));
      
      // 测试所有代理
      for (final proxyUrl in proxies) {
        final proxyToken = CancelToken();
        cancelTokens.add(proxyToken);
        futures.add(_testSingleDomain(domain, testPath, proxyToken, taskIndex++, useProxy: true, proxyUrl: proxyUrl));
      }
    }

    try {
      // 创建竞速逻辑
      final completer = Completer<DomainRacingResult?>();
      int completedCount = 0;
      final errors = <String>[];

      for (int i = 0; i < futures.length; i++) {
        futures[i].then((result) {
          if (!completer.isCompleted && result.success) {
            // 第一个成功的获胜
            final connectionType = result.useProxy ? '代理: ${result.proxyUrl}' : '直连';
            _logger.info(
                '[域名竞速] 🏆 域名 #$i (${result.domain}) [$connectionType] 获胜！响应时间: ${result.responseTime}ms');
            
            // 保存获胜结果（包含域名和代理信息）
            final racingResult = DomainRacingResult(
              domain: result.domain,
              useProxy: result.useProxy,
              proxyUrl: result.useProxy ? result.proxyUrl : null,
              responseTime: result.responseTime,
            );
            completer.complete(racingResult);

            // 注释掉取消逻辑，让所有测试都完成，方便查看每个域名+代理的连通状况
            // for (int j = 0; j < cancelTokens.length; j++) {
            //   if (j != i) cancelTokens[j].cancel();
            // }
          } else {
            completedCount++;
            if (result.error != null) {
              final connectionType = result.useProxy ? '代理: ${result.proxyUrl}' : '直连';
              _logger.info(
                  '[域名竞速] ❌ 域名 #$i (${result.domain}) [$connectionType] 失败: ${result.error}, 用时: ${result.responseTime}ms');
              errors.add('域名#$i (${result.domain}) [$connectionType]: ${result.error}');
            }

            // 如果所有测试都完成且都失败了
            if (completedCount == futures.length && !completer.isCompleted) {
              _logger.warning('[域名竞速] 所有域名测试都失败: ${errors.join('; ')}');
              completer.complete(null);
            }
          }
        }).catchError((e) {
          completedCount++;
          errors.add('域名#$i异常: $e');

          if (completedCount == futures.length && !completer.isCompleted) {
            _logger.warning('[域名竞速] 所有域名测试都失败: ${errors.join('; ')}');
            completer.complete(null);
          }
        });
      }

      // 等待第一个完成
      final winner = await completer.future;

      // 如果需要强制HTTPS结果，转换获胜域名
      if (winner != null && forceHttpsResult) {
        final httpsUrl = _convertToHttpsUrl(winner.domain);
        return DomainRacingResult(
          domain: httpsUrl,
          useProxy: winner.useProxy,
          proxyUrl: winner.proxyUrl,
          responseTime: winner.responseTime,
        );
      }

      return winner;
    } catch (e) {
      _logger.error('[域名竞速] 竞速测试异常', e);
      return null;
    }
  }

  /// 测试单个域名
  static Future<DomainTestResult> _testSingleDomain(
    String domain,
    String testPath,
    CancelToken cancelToken,
    int index, {
    bool useProxy = false,
    String? proxyUrl,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final connectionType = useProxy ? '代理: $proxyUrl' : '直连';
      _logger.info('[域名竞速] 开始测试域名 #$index: $domain [$connectionType]');

      // 构建测试URL
      final testUrl = _buildTestUrl(domain, testPath);
      _logger.info('[域名竞速] 域名 #$index 测试URL: $testUrl [$connectionType]');

      // 根据域名类型选择HttpClient配置
      final withoutProtocol = domain.replaceFirst(RegExp(r'^https?://'), '');
      final isIpWithPort = _isIpWithPort(withoutProtocol);
      
      HttpClient client;

      if (isIpWithPort && !useProxy) {
        // IP+端口 直连：使用自定义证书
        final securityContext = await _getSecurityContext();
        client = HttpClient(context: securityContext);
        _logger.info('[域名竞速] 域名 #$index 使用自定义CA证书 [$connectionType]');
      } else {
        // 域名 或 IP+端口走代理：使用默认配置
        client = HttpClient();
        _logger.info('[域名竞速] 域名 #$index 使用默认HttpClient [$connectionType]');
      }

      // 如果使用代理，配置 SOCKS5 代理
      if (useProxy && proxyUrl != null) {
        final proxyConfig = _parseProxyConfig(proxyUrl);
        final proxySettings = ProxySettings(
          InternetAddress(proxyConfig['host']!),
          int.parse(proxyConfig['port']!),
          username: proxyConfig['username'],
          password: proxyConfig['password'],
        );
        
        SocksTCPClient.assignToHttpClient(client, [proxySettings]);
        _logger.info('[域名竞速] 域名 #$index 配置SOCKS5代理: ${proxyConfig['host']}:${proxyConfig['port']}');
      }
      
      // 配置证书验证（必须在配置代理之后设置）
      if (isIpWithPort) {
        // IP+端口：完全忽略证书验证
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          _logger.info('[域名竞速] 域名 #$index 忽略证书验证: $host:$port');
          return true; // 完全接受任何证书
        };
      }

      client.connectionTimeout = _connectionTimeout;

      final uri = Uri.parse(testUrl);
      final request = await client.getUrl(uri);

      // 设置请求头
      if (_isIpWithPort(withoutProtocol)) {
        // IP+端口：使用加密User-Agent（Caddy认证）
        final apiUserAgent = await UserAgentConfig.get(UserAgentScenario.apiEncrypted);
        request.headers.set(HttpHeaders.userAgentHeader, apiUserAgent);
        _logger.info('[域名竞速] 域名 #$index 使用加密User-Agent（Caddy认证）');
      } else {
        // 域名：使用域名竞速测试User-Agent
        final domainUserAgent = await UserAgentConfig.get(UserAgentScenario.domainRacingTest);
        request.headers.set(HttpHeaders.userAgentHeader, domainUserAgent);
        _logger.info('[域名竞速] 域名 #$index 使用域名竞速测试User-Agent');
      }
      request.headers.set(HttpHeaders.acceptHeader, '*/*');

      final response = await request.close().timeout(_responseTimeout);
      client.close();

      stopwatch.stop();

      if (cancelToken.isCancelled) {
        _logger.info('[域名竞速] 域名 #$index 测试完成但已被取消');
        return DomainTestResult.failure(
            domain, '测试被取消', stopwatch.elapsedMilliseconds, useProxy: useProxy, proxyUrl: proxyUrl);
      }

      if (response.statusCode >= 200 && response.statusCode < 400) {
        final connectionType = useProxy ? '代理: $proxyUrl' : '直连';
        _logger.info(
            '[域名竞速] 🏆 域名 #$index ($domain) [$connectionType] 测试成功，响应时间: ${stopwatch.elapsedMilliseconds}ms');
        return DomainTestResult.success(domain, stopwatch.elapsedMilliseconds, useProxy: useProxy, proxyUrl: proxyUrl);
      } else {
        _logger.info('[域名竞速] 域名 #$index ($domain) 返回状态码: ${response.statusCode}');
        return DomainTestResult.failure(
            domain, 'HTTP ${response.statusCode}', stopwatch.elapsedMilliseconds, useProxy: useProxy, proxyUrl: proxyUrl);
      }
    } on TimeoutException {
      stopwatch.stop();
      _logger.info('[域名竞速] 域名 #$index ($domain) 超时');
      return DomainTestResult.failure(
          domain, '连接超时', stopwatch.elapsedMilliseconds, useProxy: useProxy, proxyUrl: proxyUrl);
    } catch (e) {
      stopwatch.stop();
      if (cancelToken.isCancelled) {
        _logger.info('[域名竞速] 域名 #$index ($domain) 被正常取消');
        return DomainTestResult.failure(
            domain, '测试被取消', stopwatch.elapsedMilliseconds, useProxy: useProxy, proxyUrl: proxyUrl);
      }

      _logger.info('[域名竞速] 域名 #$index ($domain) 测试失败: $e');
      return DomainTestResult.failure(
          domain, '连接失败: $e', stopwatch.elapsedMilliseconds, useProxy: useProxy, proxyUrl: proxyUrl);
    }
  }

  /// 构建测试URL
  static String _buildTestUrl(String domain, String testPath) {
    String baseUrl;

    if (domain.startsWith('http')) {
      // 已有协议前缀，强制转换为HTTPS
      final withoutProtocol = domain.replaceFirst(RegExp(r'^https?://'), '');
      baseUrl = 'https://$withoutProtocol';
    } else {
      // 无协议前缀，统一使用HTTPS
      baseUrl = 'https://$domain';
    }

    final withoutProtocol = baseUrl.replaceFirst('https://', '');
    if (_isIpWithPort(withoutProtocol)) {
      _logger.info('[域名竞速] IP+端口使用HTTPS+CA证书测试: $baseUrl');
    } else {
      _logger.info('[域名竞速] 域名使用HTTPS测试: $baseUrl');
    }

    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    if (testPath.isEmpty) {
      // 使用健康检查端点
      return '$baseUrl/api/v1/guest/comm/config';
    } else {
      String path = testPath.startsWith('/') ? testPath : '/$testPath';
      return '$baseUrl$path';
    }
  }

  /// 判断是否为 IP+端口格式
  static bool _isIpWithPort(String domain) {
    // IP+端口格式正则：匹配 IPv4 或 IPv6 地址 + 端口号
    final ipPortPattern = RegExp(
      r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|'
      r'\[?[0-9a-fA-F:]+\]?)'
      r':\d+$',
    );
    return ipPortPattern.hasMatch(domain);
  }

  /// 解析代理配置
  ///
  /// 输入格式:
  /// - `socks5://user:pass@host:port`
  /// - `socks5://host:port`
  /// - `http://user:pass@host:port`
  ///
  /// 返回: { host, port, username?, password? }
  static Map<String, String?> _parseProxyConfig(String proxyUrl) {
    String url = proxyUrl.trim();

    // 去除协议前缀
    if (url.toLowerCase().startsWith('socks5://')) {
      url = url.substring(9);
    } else if (url.toLowerCase().startsWith('http://')) {
      url = url.substring(7);
    } else if (url.toLowerCase().startsWith('https://')) {
      url = url.substring(8);
    }

    String? username;
    String? password;
    String hostPort = url;

    // 解析认证信息 user:pass@host:port
    if (url.contains('@')) {
      final atIndex = url.lastIndexOf('@');
      final authPart = url.substring(0, atIndex);
      hostPort = url.substring(atIndex + 1);

      if (authPart.contains(':')) {
        final colonIndex = authPart.indexOf(':');
        username = authPart.substring(0, colonIndex);
        password = authPart.substring(colonIndex + 1);
      }
    }

    // 解析 host:port
    final colonIndex = hostPort.lastIndexOf(':');
    if (colonIndex == -1) {
      throw FormatException('代理配置格式错误，缺少端口号: $proxyUrl');
    }

    final host = hostPort.substring(0, colonIndex);
    final port = hostPort.substring(colonIndex + 1);

    if (host.isEmpty || port.isEmpty) {
      throw FormatException('代理配置格式错误: $proxyUrl');
    }

    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }

  /// 转换域名为HTTPS格式（用于SDK初始化）
  static String _convertToHttpsUrl(String domain) {
    if (domain.startsWith('https://')) {
      return domain;
    } else if (domain.startsWith('http://')) {
      // 如果是HTTP的IP+端口，转换为HTTPS
      final withoutHttp = domain.substring(7); // 移除 "http://"
      return 'https://$withoutHttp';
    } else {
      // 纯域名，添加HTTPS前缀
      return 'https://$domain';
    }
  }

  /// 批量测试所有域名的延迟（不竞速）
  ///
  /// [domains] 要测试的域名列表
  /// [testPath] 用于测试的路径
  ///
  /// 返回所有域名的测试结果
  static Future<List<DomainTestResult>> testAllDomains(
    List<String> domains, {
    String testPath = '',
  }) async {
    if (domains.isEmpty) return [];

    _logger.info('[域名测试] 开始测试 ${domains.length} 个域名的延迟');

    final List<Future<DomainTestResult>> futures =
        domains.asMap().entries.map((entry) {
      final index = entry.key;
      final domain = entry.value;
      return _testSingleDomain(domain, testPath, CancelToken(), index);
    }).toList();

    final results = await Future.wait(futures);

    // 按响应时间排序
    results.sort((a, b) {
      if (a.success && !b.success) return -1;
      if (!a.success && b.success) return 1;
      if (a.success && b.success) {
        return a.responseTime.compareTo(b.responseTime);
      }
      return 0;
    });

    _logger.info(
        '[域名测试] 测试完成，成功: ${results.where((r) => r.success).length}/${results.length}');
    return results;
  }
}

/// 域名竞速结果
class DomainRacingResult {
  final String domain; // 获胜域名
  final bool useProxy; // 是否使用代理
  final String? proxyUrl; // 代理地址（如果使用代理）
  final int responseTime; // 响应时间（毫秒）

  const DomainRacingResult({
    required this.domain,
    required this.useProxy,
    this.proxyUrl,
    required this.responseTime,
  });

  @override
  String toString() {
    final proxyInfo = useProxy ? ' [代理: $proxyUrl]' : ' [直连]';
    return 'DomainRacingResult(domain: $domain$proxyInfo, responseTime: ${responseTime}ms)';
  }
}

/// 域名测试结果
class DomainTestResult {
  final String domain;
  final bool success;
  final int responseTime;
  final String? error;
  final bool useProxy; // 是否使用代理
  final String? proxyUrl; // 使用的代理地址

  const DomainTestResult._({
    required this.domain,
    required this.success,
    required this.responseTime,
    this.error,
    this.useProxy = false,
    this.proxyUrl,
  });

  factory DomainTestResult.success(String domain, int responseTime, {bool useProxy = false, String? proxyUrl}) {
    return DomainTestResult._(
      domain: domain,
      success: true,
      responseTime: responseTime,
      useProxy: useProxy,
      proxyUrl: proxyUrl,
    );
  }

  factory DomainTestResult.failure(
      String domain, String error, int responseTime, {bool useProxy = false, String? proxyUrl}) {
    return DomainTestResult._(
      domain: domain,
      success: false,
      responseTime: responseTime,
      error: error,
      useProxy: useProxy,
      proxyUrl: proxyUrl,
    );
  }

  @override
  String toString() {
    final proxyInfo = useProxy ? ' [代理: $proxyUrl]' : ' [直连]';
    if (success) {
      return 'DomainTestResult(domain: $domain$proxyInfo, success: $success, responseTime: ${responseTime}ms)';
    } else {
      return 'DomainTestResult(domain: $domain$proxyInfo, success: $success, error: $error, responseTime: ${responseTime}ms)';
    }
  }
}

/// 取消令牌
class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

