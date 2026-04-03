import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('relay_http_adapter');

/// 原始 HttpOverrides，绕过全局 FlClash HttpOverrides
class _RawHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

final HttpOverrides _rawHttpOverrides = _RawHttpOverrides();

/// GET 请求缓存条目（3 秒 TTL）
class _CachedResponse {
  final int statusCode;
  final Uint8List body;
  final Map<String, List<String>> headers;
  final String? statusMessage;
  final DateTime createdAt;

  _CachedResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    this.statusMessage,
  }) : createdAt = DateTime.now();

  /// 大响应（>50KB）缓存 30 秒，小响应缓存 3 秒
  bool get isExpired {
    final ttl = body.length > 50 * 1024 ? 30 : 3;
    return DateTime.now().difference(createdAt).inSeconds > ttl;
  }

  ResponseBody toResponseBody() => ResponseBody(
    Stream.value(Uint8List.fromList(body)),
    statusCode,
    headers: Map<String, List<String>>.from(headers),
    statusMessage: statusMessage,
  );
}

/// Relay HTTP 适配器
///
/// 替换 Dio 的传输层，将所有 HTTP 请求通过 Relay 中继服务器转发。
/// 因为工作在传输层，SDK 的所有拦截器（反混淆、认证、日志）仍然正常运行。
///
/// 优化策略：
/// 1. 持久化 HttpClient 连接池（复用 TCP 连接）
/// 2. GET 请求 3 秒缓存（避免重复调用同一接口）
/// 3. 相同 URL 的 GET 请求去重（并发时复用同一请求）
/// 4. 直连 Relay IP（不走 SOCKS5，DPI 只拦截域名 SNI，不拦截 IP）
///
/// Relay 协议: POST http://IP:PORT/r，通过 X-K/X-T/X-M/X-H 头传递目标请求信息
/// 流程: App → Relay 服务器（IP 直连）→ 目标域名
class RelayHttpClientAdapter implements HttpClientAdapter {
  final String relayUrl;
  late final List<Map<String, String>> _endpoints;

  /// 持久化 HttpClient 池 (key = "host:port")
  final Map<String, HttpClient> _clients = {};

  /// GET 请求短期缓存（3 秒 TTL，避免重复 API 请求）
  final Map<String, _CachedResponse> _getCache = {};

  /// 进行中的 GET 请求去重（相同 URL 复用同一个 Future）
  final Map<String, Future<_CachedResponse>> _inflightGets = {};

  /// 缓存代号：每次写操作(POST/PUT/DELETE)递增。
  /// GET 请求发起时记录当前代号，完成后仅当代号未变才写入缓存，
  /// 防止 POST 清缓存后在途 GET 把旧数据写回。
  int _cacheGeneration = 0;

  RelayHttpClientAdapter({required this.relayUrl}) {
    _endpoints = _parseRelayUrl(relayUrl);
    _logger.info('[RelayAdapter] 初始化完成，端点数: ${_endpoints.length}');
  }

  /// 获取或创建指定端点的持久化 HttpClient（直连 IP，不走 SOCKS5）
  HttpClient _getOrCreateClient(Map<String, String> endpoint, Duration connectTimeout) {
    final key = '${endpoint['host']}:${endpoint['port']}';
    if (_clients.containsKey(key)) return _clients[key]!;

    _logger.info('[RelayAdapter] 创建持久化 HttpClient: $key');
    // 绕过全局 FlClash HttpOverrides，直连 Relay IP
    final client = HttpOverrides.runZoned(
      () => HttpClient(),
      createHttpClient: _rawHttpOverrides.createHttpClient,
    )!;
    client.findProxy = (_) => 'DIRECT';
    client.connectionTimeout = connectTimeout;
    client.badCertificateCallback = (_, __, ___) => true;
    client.idleTimeout = const Duration(seconds: 60);
    client.maxConnectionsPerHost = 6;

    _clients[key] = client;
    return client;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final targetUrl = options.uri.toString();

    // ── GET 请求：缓存 + 去重 ──
    if (options.method == 'GET') {
      // 1. 检查缓存（3 秒 TTL）
      final cached = _getCache[targetUrl];
      if (cached != null && !cached.isExpired) {
        _logger.info('[RelayAdapter] 缓存命中: $targetUrl (${cached.body.length} bytes)');
        return cached.toResponseBody();
      }
      if (cached != null) _getCache.remove(targetUrl);

      // 2. 复用进行中的相同请求（去重）
      final inflight = _inflightGets[targetUrl];
      if (inflight != null) {
        _logger.info('[RelayAdapter] 复用进行中请求: $targetUrl');
        final result = await inflight;
        return result.toResponseBody();
      }

      // 3. 发起新请求并注册去重
      final completer = Completer<_CachedResponse>();
      _inflightGets[targetUrl] = completer.future;
      final genAtStart = _cacheGeneration;

      try {
        _logger.info('[RelayAdapter] 转发: GET $targetUrl');
        final result = await _doRelay(options, targetUrl, const []);
        // 仅当请求期间没有写操作(POST/PUT/DELETE)发生时才写入缓存
        // 防止 POST 清缓存后，在途 GET 把旧数据写回
        if (_cacheGeneration == genAtStart) {
          _getCache[targetUrl] = result;
        }
        completer.complete(result);
        return result.toResponseBody();
      } catch (e) {
        completer.completeError(e);
        rethrow;
      } finally {
        _inflightGets.remove(targetUrl);
      }
    }

    // ── POST/PUT/DELETE：直接转发 ──
    _logger.info('[RelayAdapter] 转发: ${options.method} $targetUrl');

    final requestBodyBytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        requestBodyBytes.addAll(chunk);
      }
    }

    // 写操作后清除缓存并递增代号（防止在途 GET 写回旧数据）
    _getCache.clear();
    _inflightGets.clear();
    _cacheGeneration++;

    final result = await _doRelay(options, targetUrl, requestBodyBytes);
    return result.toResponseBody();
  }

  /// 尝试所有 Relay 端点转发（IPv4 优先）
  Future<_CachedResponse> _doRelay(
    RequestOptions options,
    String targetUrl,
    List<int> requestBody,
  ) async {
    Object? lastError;
    for (final ep in _endpoints) {
      final epLabel = ep['host']!.contains(':') ? 'IPv6' : 'IPv4';
      try {
        _logger.info('[RelayAdapter] 尝试 $epLabel: ${ep['host']}:${ep['port']}');
        return await _sendViaRelay(
          options,
          targetUrl: targetUrl,
          endpoint: ep,
          requestBody: requestBody,
        );
      } catch (e) {
        lastError = e;
        _logger.warning('[RelayAdapter] $epLabel 失败: $e');
      }
    }

    throw DioException(
      requestOptions: options,
      error: lastError ?? 'Relay 中继请求全部失败',
      type: DioExceptionType.connectionError,
    );
  }

  Future<_CachedResponse> _sendViaRelay(
    RequestOptions options, {
    required String targetUrl,
    required Map<String, String> endpoint,
    required List<int> requestBody,
  }) async {
    final relayHost = endpoint['host']!;
    final relayPort = int.parse(endpoint['port']!);
    final relayAuthKey = endpoint['authKey']!;

    final client = _getOrCreateClient(
      endpoint,
      options.connectTimeout ?? const Duration(seconds: 15),
    );

    try {
      final relayHostForUrl = relayHost.contains(':') ? '[$relayHost]' : relayHost;
      final relayUri = Uri.parse('http://$relayHostForUrl:$relayPort/r');
      final request = await client.postUrl(relayUri);

      request.headers.set('X-K', relayAuthKey);
      request.headers.set('X-T', base64Encode(utf8.encode(targetUrl)));
      request.headers.set('X-M', options.method);

      final customHeaders = <String, String>{};
      options.headers.forEach((key, value) {
        if (value != null) customHeaders[key] = value.toString();
      });
      request.headers.set('X-H', base64Encode(utf8.encode(jsonEncode(customHeaders))));

      if (requestBody.isNotEmpty) {
        request.headers.set(HttpHeaders.contentLengthHeader, requestBody.length.toString());
        request.add(requestBody);
      } else {
        request.headers.set(HttpHeaders.contentLengthHeader, '0');
      }

      final httpResponse = await request.close().timeout(
        options.receiveTimeout ?? const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Relay请求超时'),
      );

      if (httpResponse.statusCode != 200) {
        throw HttpException('Relay HTTP ${httpResponse.statusCode}');
      }

      final originalStatus = int.tryParse(httpResponse.headers.value('X-S') ?? '') ?? 200;

      final bytes = await httpResponse.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      final responseHeaders = <String, List<String>>{};
      final rhHeader = httpResponse.headers.value('X-RH');
      if (rhHeader != null && rhHeader.isNotEmpty) {
        try {
          final originalHeaders =
              jsonDecode(utf8.decode(base64Decode(rhHeader))) as Map<String, dynamic>;
          originalHeaders.forEach((key, value) {
            responseHeaders[key.toLowerCase()] = [value.toString()];
          });
        } catch (e) {
          _logger.warning('[RelayAdapter] 解析原始响应头失败: $e');
        }
      }

      _logger.info('[RelayAdapter] ✅ Relay 请求成功: $originalStatus, ${bytes.length} bytes');

      return _CachedResponse(
        statusCode: originalStatus,
        body: Uint8List.fromList(bytes),
        headers: responseHeaders,
        statusMessage: httpResponse.reasonPhrase,
      );
    } catch (e) {
      final key = '${endpoint['host']}:${endpoint['port']}';
      _invalidateClient(key);
      rethrow;
    }
  }

  void _invalidateClient(String key) {
    final client = _clients.remove(key);
    client?.close(force: true);
    _logger.info('[RelayAdapter] 已销毁失效客户端: $key');
  }

  @override
  void close({bool force = false}) {
    for (final client in _clients.values) {
      client.close(force: force);
    }
    _clients.clear();
    _getCache.clear();
    _inflightGets.clear();
  }

  /// 解析 relay:// URL（支持双栈）
  static List<Map<String, String>> _parseRelayUrl(String relayUrl) {
    String url = relayUrl.trim();
    if (url.toLowerCase().startsWith('relay://')) {
      url = url.substring(8);
    }

    if (!url.contains('@')) {
      throw FormatException('Relay URL 格式错误，缺少认证密钥: $relayUrl');
    }

    final atIndex = url.lastIndexOf('@');
    final authKey = url.substring(0, atIndex);
    final endpointsPart = url.substring(atIndex + 1);

    final segments = endpointsPart.split('|');
    final results = <Map<String, String>>[];

    for (final seg in segments) {
      final trimmed = seg.trim();
      if (trimmed.isEmpty) continue;

      String host;
      String port;

      if (trimmed.startsWith('[')) {
        final closeBracket = trimmed.indexOf(']');
        if (closeBracket == -1) {
          throw FormatException('Relay URL IPv6 格式错误: $relayUrl');
        }
        host = trimmed.substring(1, closeBracket);
        if (closeBracket + 1 < trimmed.length && trimmed[closeBracket + 1] == ':') {
          port = trimmed.substring(closeBracket + 2);
        } else {
          port = '';
        }
      } else {
        final colonIndex = trimmed.lastIndexOf(':');
        if (colonIndex == -1) {
          host = trimmed;
          port = '';
        } else {
          host = trimmed.substring(0, colonIndex);
          port = trimmed.substring(colonIndex + 1);
        }
      }

      results.add({'authKey': authKey, 'host': host, 'port': port});
    }

    if (results.isEmpty) {
      throw FormatException('Relay URL 格式错误: $relayUrl');
    }

    final defaultPort = results.firstWhere(
      (e) => e['port']!.isNotEmpty,
      orElse: () => throw FormatException('Relay URL 缺少端口号: $relayUrl'),
    )['port']!;
    for (final ep in results) {
      if (ep['port']!.isEmpty) ep['port'] = defaultPort;
    }

    // IPv4 优先
    results.sort((a, b) {
      final aIsV4 = !a['host']!.contains(':');
      final bIsV4 = !b['host']!.contains(':');
      if (aIsV4 && !bIsV4) return -1;
      if (!aIsV4 && bIsV4) return 1;
      return 0;
    });

    return results;
  }
}
