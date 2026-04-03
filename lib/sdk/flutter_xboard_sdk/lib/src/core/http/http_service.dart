import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../exceptions/xboard_exceptions.dart';
import '../auth/token_manager.dart';
import '../auth/auth_interceptor.dart';
import '../logging/sdk_logger.dart';
import 'http_config.dart';

class HttpService {
  final String baseUrl;
  final HttpConfig httpConfig;
  late final Dio _dio;
  TokenManager? _tokenManager;
  AuthInterceptor? _authInterceptor;
  String? _expectedCertificatePem;
  bool _certificateLoadFailed = false;
  InternetAddress? _resolvedProxyAddress; // 预解析的代理地址（支持域名）

  HttpService._internal(
    this.baseUrl,
    this.httpConfig,
    this._tokenManager,
  );

  /// 创建 HttpService 实例（异步工厂方法）
  static Future<HttpService> create(
    String baseUrl, {
    TokenManager? tokenManager,
    HttpConfig? httpConfig,
  }) async {
    final config = httpConfig ?? HttpConfig.defaultConfig();
    final service = HttpService._internal(baseUrl, config, tokenManager);
    
    // 如果启用证书固定，先加载证书
    if (config.enableCertificatePinning == true) {
      await service._loadClientCertificate();
    }
    
    // 预解析代理域名（createHttpClient 是同步回调，无法 await）
    if (config.proxyUrl != null && config.proxyUrl!.isNotEmpty) {
      await service._resolveProxyAddress(config.proxyUrl!);
    }
    
    // 初始化 Dio
    service._initializeDio();
    
    return service;
  }

  /// 预解析代理地址（支持域名和IP）
  Future<void> _resolveProxyAddress(String proxyUrl) async {
    final proxyConfig = _parseProxyConfig(proxyUrl);
    final proxyHost = proxyConfig['host']!;
    try {
      _resolvedProxyAddress = InternetAddress(proxyHost);
    } on ArgumentError {
      // 不是 IP 地址，是域名，需要 DNS 解析
      final addresses = await InternetAddress.lookup(proxyHost);
      if (addresses.isEmpty) {
        throw Exception('无法解析代理域名: $proxyHost');
      }
      _resolvedProxyAddress = addresses.first;
      SdkLogger.i('[XBoardSDK] 代理域名 $proxyHost 解析为 ${_resolvedProxyAddress!.address}');
    }
  }

  /// 初始化Dio配置
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: httpConfig.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: httpConfig.receiveTimeoutSeconds),
      sendTimeout: Duration(seconds: httpConfig.sendTimeoutSeconds),
      responseType: ResponseType.plain,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // 使用配置的 User-Agent，如果未设置则使用默认值
        'User-Agent': httpConfig.userAgent ?? 'FlClash-XBoard-SDK/1.0',
      },
    ));

    // 配置客户端证书和SSL验证
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      SdkLogger.d('[XBoardSDK] 🔨 创建 HttpClient...');
      final client = HttpClient();

      // 配置代理
      if (httpConfig.proxyUrl != null && httpConfig.proxyUrl!.isNotEmpty) {
        SdkLogger.d('[XBoardSDK] 🔌 配置代理: ${httpConfig.proxyUrl}');

        final proxyConfig = _parseProxyConfig(httpConfig.proxyUrl!);
        SdkLogger.d('[XBoardSDK] 🔄 解析: host=${proxyConfig['host']}, port=${proxyConfig['port']}, auth=${proxyConfig['username'] != null}');

        // 使用 socks5_proxy 配置代理（使用预解析的地址，支持域名）
        final proxySettings = ProxySettings(
          _resolvedProxyAddress ?? InternetAddress(proxyConfig['host']!),
          int.parse(proxyConfig['port']!),
          username: proxyConfig['username'],
          password: proxyConfig['password'],
        );

        SocksTCPClient.assignToHttpClientWithSecureOptions(
          client,
          [proxySettings],
          onBadCertificate: (_) => true, // SOCKS5代理的TLS由SecureSocket.secure()处理，需在此传入
        );
        SdkLogger.i('[XBoardSDK] ✅ SOCKS5 代理配置完成');
      }
      
      // 配置SSL证书验证
      if (httpConfig.enableCertificatePinning || httpConfig.ignoreCertificateHostname) {
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          // 如果启用了证书固定，进行严格验证
          if (httpConfig.enableCertificatePinning) {
            return _verifyCertificate(cert, host, port);
          }
          // 如果允许忽略主机名验证（仅开发环境）
          if (httpConfig.ignoreCertificateHostname) {
            return true;
          }
          // 默认使用标准验证
          return false;
        };
      }
      
      return client;
    };

    // 添加拦截器（生产环境移除日志拦截器）

    // 添加请求日志和响应格式化拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 打印请求信息和代理状态
        final fullUrl = options.uri.toString();
        final proxyStatus = httpConfig.proxyUrl != null && httpConfig.proxyUrl!.isNotEmpty;
        final proxyInfo = proxyStatus ? httpConfig.proxyUrl : 'DIRECT';
        SdkLogger.d('[XBoardSDK] 📡 ${options.method} $fullUrl | proxy: $proxyStatus ($proxyInfo)');

        handler.next(options);
      },
      onResponse: (response, handler) {
        // 仅对文本响应进行解混淆和格式化（跳过二进制/字节响应）
        if (response.data is String) {
          response.data = _deobfuscateResponse(response);
          response.data = _normalizeResponse(response.data);
        }
        handler.next(response);
      },
      onError: (error, handler) {
        final normalizedError = _handleDioError(error);
        handler.next(normalizedError);
      },
    ));

    // 添加认证拦截器（最后添加，确保它能处理认证相关错误）
    if (_tokenManager != null) {
      _authInterceptor = AuthInterceptor(tokenManager: _tokenManager!);
      _dio.interceptors.add(_authInterceptor!);
    }
  }

  /// 设置TokenManager
  void setTokenManager(TokenManager tokenManager) {
    _tokenManager = tokenManager;
    
    // 移除旧的认证拦截器
    if (_authInterceptor != null) {
      _dio.interceptors.remove(_authInterceptor!);
    }
    
    // 添加新的认证拦截器
    _authInterceptor = AuthInterceptor(tokenManager: tokenManager);
    _dio.interceptors.add(_authInterceptor!);
  }

  /// 发送GET请求
  Future<Map<String, dynamic>> getRequest(String path, {Map<String, String>? headers, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _convertDioError(e);
    }
  }

  /// 发送POST请求
  Future<Map<String, dynamic>> postRequest(String path, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(headers: headers),
      );
      
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _convertDioError(e);
    }
  }

  /// 发送PUT请求
  Future<Map<String, dynamic>> putRequest(String path, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        options: Options(headers: headers),
      );
      
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _convertDioError(e);
    }
  }

  /// 发送DELETE请求
  Future<Map<String, dynamic>> deleteRequest(String path, {Map<String, String>? headers}) async {
    try {
      final response = await _dio.delete(
        path,
        options: Options(headers: headers),
      );
      
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _convertDioError(e);
    }
  }

  /// 上传文件（multipart/form-data）
  ///
  /// [path] 接口路径
  /// [fieldName] 表单字段名
  /// [fileBytes] 文件字节数据
  /// [fileName] 文件名
  /// [mimeType] MIME 类型，如 'image/png'
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String fieldName,
    required List<int> fileBytes,
    required String fileName,
    String? mimeType,
    Map<String, String>? headers,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: mimeType != null
              ? DioMediaType.parse(mimeType)
              : null,
        ),
      });

      // 构建请求头：移除 Content-Type，让 Dio 根据 FormData 自动生成带 boundary 的值
      final uploadHeaders = <String, dynamic>{
        ...?headers,
      };
      // 确保不传 Content-Type / content-type，Dio 遇到 FormData 会自动设置
      uploadHeaders.remove('Content-Type');
      uploadHeaders.remove('content-type');

      SdkLogger.d('[HttpService] 📤 上传文件: $path, fileName=$fileName, size=${fileBytes.length}');

      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          headers: uploadHeaders,
          // 显式设置为 multipart/form-data，Dio 会自动追加 boundary
          contentType: 'multipart/form-data',
          // 覆盖超时：大文件上传需要更长时间
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      SdkLogger.d('[HttpService] ✅ 上传成功: ${response.statusCode}');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      SdkLogger.e('[HttpService] ❌ 上传失败: $e');
      throw _convertDioError(e);
    }
  }

  /// 下载原始字节数据（用于图片等二进制内容）
  ///
  /// 走同一条网络通道（代理、SSL），但跳过 JSON 解析
  /// [url] 可以是完整 URL 或相对路径，完整 URL 会自动转为相对路径
  Future<Uint8List> downloadBytes(String url) async {
    try {
      // 如果是完整 URL，提取路径部分，确保走 baseUrl 的连接池和代理
      String requestPath = url;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final uri = Uri.parse(url);
        requestPath = uri.path;
        if (uri.query.isNotEmpty) {
          requestPath = '$requestPath?${uri.query}';
        }
        SdkLogger.d('[HttpService] 📥 URL转为相对路径: $url → $requestPath');
      }

      SdkLogger.d('[HttpService] 📥 下载资源: $requestPath');
      final response = await _dio.get<List<int>>(
        requestPath,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': '*/*',
          },
          contentType: null,
        ),
      );
      SdkLogger.d('[HttpService] ✅ 下载完成: ${response.data?.length ?? 0} bytes');
      return Uint8List.fromList(response.data ?? []);
    } catch (e) {
      SdkLogger.e('[HttpService] ❌ 下载失败: $e');
      throw _convertDioError(e);
    }
  }

  /// 解混淆响应数据
  /// 
  /// 根据配置的混淆前缀自动检测并反混淆响应数据
  /// 例如 Caddy 混淆规则：replace "{\"status\"" "OBFS_9K8L7M6N_{\"status\""
  dynamic _deobfuscateResponse(Response response) {
    try {
      final responseText = response.data as String;
      
      // 检查是否启用了自动反混淆且配置了混淆前缀
      if (httpConfig.enableAutoDeobfuscation && 
          httpConfig.obfuscationPrefix != null &&
          httpConfig.obfuscationPrefix!.isNotEmpty) {
        
        // 检测是否包含混淆前缀
        final containsObfuscationPrefix = responseText.contains(httpConfig.obfuscationPrefix!);
        
        if (containsObfuscationPrefix) {
          // 反混淆：移除混淆前缀
          final deobfuscated = responseText.replaceAll(httpConfig.obfuscationPrefix!, '');
          return jsonDecode(deobfuscated);
        }
      }
      
      // 没有混淆或未启用反混淆，尝试直接解析JSON
      if (responseText.trim().startsWith('{') || responseText.trim().startsWith('[')) {
        return jsonDecode(responseText);
      } else {
        return responseText;
      }
    } catch (e) {
      // 解混淆失败，返回原始数据
      return response.data;
    }
  }

  /// 验证客户端证书（Certificate Pinning）
  /// 
  /// ⚠️ 安全改进：证书加载失败时拒绝连接
  /// [cert] 服务器证书
  /// [host] 主机名
  /// [port] 端口
  bool _verifyCertificate(X509Certificate cert, String host, int port) {
    try {
      SdkLogger.i('[HttpService] 🔐 开始验证证书: $host:$port');
      
      // 安全检查：如果证书加载失败，拒绝连接
      if (_certificateLoadFailed) {
        SdkLogger.e('[HttpService] ❌ 证书加载失败，拒绝连接');
        throw CertificateException(
          'Certificate pinning is enabled but certificate failed to load. '
          'Refusing connection for security reasons.'
        );
      }

      // 安全检查：如果启用了证书固定但没有期望的证书，拒绝连接
      if (httpConfig.enableCertificatePinning && _expectedCertificatePem == null) {
        SdkLogger.e('[HttpService] ❌ 证书固定已启用但未加载期望证书');
        throw CertificateException(
          'Certificate pinning is enabled but no expected certificate is available. '
          'Refusing connection for security reasons.'
        );
      }
      
      // 打印服务器证书信息
      SdkLogger.i('[HttpService] 📜 服务器证书信息:');
      SdkLogger.i('[HttpService]   - 主体: ${cert.subject}');
      SdkLogger.i('[HttpService]   - 签发者: ${cert.issuer}');
      SdkLogger.i('[HttpService]   - 有效期: ${cert.startValidity} ~ ${cert.endValidity}');
      
      // 获取当前证书的PEM格式
      final currentCertPem = cert.pem;
      
      SdkLogger.i('[HttpService] 🔍 比较证书指纹...');
      SdkLogger.i('[HttpService]   - 期望证书长度: ${_expectedCertificatePem!.length} 字符');
      SdkLogger.i('[HttpService]   - 服务器证书长度: ${currentCertPem.length} 字符');
      
      // 比较证书内容（忽略空白字符差异）
      final expectedNormalized = _expectedCertificatePem!.replaceAll(RegExp(r'\s+'), '');
      final currentNormalized = currentCertPem.replaceAll(RegExp(r'\s+'), '');
      
      SdkLogger.i('[HttpService]   - 标准化后期望证书长度: ${expectedNormalized.length}');
      SdkLogger.i('[HttpService]   - 标准化后服务器证书长度: ${currentNormalized.length}');
      
      final isValid = expectedNormalized == currentNormalized;
      
      if (!isValid) {
        SdkLogger.e('[HttpService] ❌ 证书不匹配！');
        SdkLogger.e('[HttpService]   - 期望证书前100字符: ${expectedNormalized.substring(0, 100.clamp(0, expectedNormalized.length))}');
        SdkLogger.e('[HttpService]   - 服务器证书前100字符: ${currentNormalized.substring(0, 100.clamp(0, currentNormalized.length))}');
        throw CertificateException(
          'Certificate verification failed for $host:$port. '
          'The certificate does not match the expected certificate.'
        );
      }
      
      SdkLogger.i('[HttpService] ✅ 证书验证成功！');
      return isValid;
    } catch (e) {
      // 证书验证出错，为安全起见拒绝连接
      SdkLogger.e('[HttpService] ⛔ 证书验证异常: $e');
      return false;
    }
  }
  
  /// 加载客户端证书
  /// 
  /// 从配置文件指定的路径加载证书（xboard.config.yaml -> security.certificate.path）
  /// 证书加载失败时会拒绝所有 HTTPS 连接以保证安全
  Future<void> _loadClientCertificate() async {
    SdkLogger.i('[HttpService] 📋 开始加载证书...');
    SdkLogger.i('[HttpService]   - 证书固定: ${httpConfig.enableCertificatePinning}');
    SdkLogger.i('[HttpService]   - 证书路径: ${httpConfig.certificatePath}');
    
    if (httpConfig.certificatePath == null || httpConfig.certificatePath!.isEmpty) {
      _certificateLoadFailed = true;
      _expectedCertificatePem = null;
      SdkLogger.w('[HttpService] ⚠️ 证书路径未配置');
      return;
    }

    final certPath = httpConfig.certificatePath!;

    try {
      SdkLogger.i('[HttpService] 🔄 正在从 assets 加载证书: $certPath');
      
      // 同步等待证书加载
      final certContent = await rootBundle.loadString(certPath);
      
      _expectedCertificatePem = certContent;
      _certificateLoadFailed = false;
      
      SdkLogger.i('[HttpService] ✅ 证书加载成功！');
      SdkLogger.i('[HttpService]   - 证书内容长度: ${certContent.length} 字符');
      SdkLogger.i('[HttpService]   - 证书前100字符: ${certContent.substring(0, 100.clamp(0, certContent.length))}');
      
    } catch (error) {
      _certificateLoadFailed = true;
      _expectedCertificatePem = null;
      SdkLogger.e('[HttpService] ❌ 证书加载失败！');
      SdkLogger.e('[HttpService]   - 错误: $error');
      SdkLogger.e('[HttpService]   - 所有 HTTPS 连接将被拒绝');
    }
  }

  /// 标准化响应格式
  Map<String, dynamic> _normalizeResponse(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) {
      return {
        'success': true,
        'data': responseData,
      };
    }

    final jsonResponse = responseData;

    // 兼容两种响应格式：
    // 1. XBoard格式: {status: "success", data: {...}}
    // 2. 通用格式: {success: true, data: {...}}
    
    if (jsonResponse.containsKey('status')) {
      // XBoard格式 -> 转换为通用格式
      return {
        'success': jsonResponse['status'] == 'success',
        'status': jsonResponse['status'],
        'message': jsonResponse['message'],
        'data': jsonResponse['data'],
        'total': jsonResponse['total'],
      };
    } else if (jsonResponse.containsKey('success')) {
      // 已经是通用格式，直接返回
      return jsonResponse;
    } else {
      // 其他格式，包装为通用格式
      return {
        'success': true,
        'data': jsonResponse,
      };
    }
  }

  /// 处理Dio错误
  DioException _handleDioError(DioException error) {
    if (error.response != null) {
      final statusCode = error.response!.statusCode!;
      
      String errorMessage = '请求失败 (状态码: $statusCode)';
      dynamic responseData;

      // 仅对文本响应进行解混淆，跳过二进制响应
      if (error.response!.data is String) {
        responseData = _deobfuscateResponse(error.response!);
      } else {
        responseData = error.response!.data;
      }
      
      // 打印响应数据以便调试
      SdkLogger.w('[HttpService] Error Response (status: $statusCode): $responseData');
      
      // 尝试从响应中提取错误信息
      if (responseData is Map<String, dynamic>) {
        // 优先级：message > error > data
        if (responseData.containsKey('message') && 
            responseData['message'] != null && 
            responseData['message'].toString().isNotEmpty) {
          errorMessage = responseData['message'].toString();
        } else if (responseData.containsKey('error') && 
                   responseData['error'] != null &&
                   responseData['error'].toString().isNotEmpty) {
          // error 可能是字符串或对象
          final errorField = responseData['error'];
          if (errorField is String) {
            errorMessage = errorField;
          } else if (errorField is Map) {
            errorMessage = errorField.toString();
          }
        } else if (responseData.containsKey('data') && responseData['data'] is String) {
          errorMessage = responseData['data'].toString();
        }
      } else if (responseData is String && responseData.isNotEmpty) {
        // 如果响应是纯文本，尝试提取有用信息
        errorMessage = responseData;
      }
      
      SdkLogger.w('[HttpService] Extracted error message: $errorMessage');

      // 创建新的DioException，保持原有的错误信息但添加我们的错误消息
      return DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: errorMessage,
        message: errorMessage,
      );
    }
    
    return error;
  }

  /// 转换Dio错误为XBoard异常
  XBoardException _convertDioError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final statusCode = error.response!.statusCode!;
        // 直接使用已经提取的错误消息（在 _handleDioError 中处理）
        final errorMessage = error.message ?? error.error?.toString() ?? '请求失败';
        
        if (statusCode == 401) {
          return AuthException(errorMessage);
        } else if (statusCode >= 400 && statusCode < 500) {
          return ApiException(errorMessage, statusCode);
        } else {
          return NetworkException(errorMessage);
        }
      } else {
        // 网络错误 - 直接使用 Dio 的原始错误信息
        String errorMsg = error.error?.toString() ?? error.message ?? error.type.toString();
        return NetworkException(errorMsg);
      }
    } else if (error is XBoardException) {
      return error;
    } else {
      return ApiException(error.toString());
    }
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }

  /// 获取Dio实例（用于高级用法）
  Dio get dio => _dio;

  /// 获取TokenManager
  TokenManager? get tokenManager => _tokenManager;

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
    final parts = hostPort.split(':');
    final host = parts[0];
    final port = parts.length > 1 ? parts[1] : '1080';

    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }
} 