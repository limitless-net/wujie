/// XBoard 数据存储服务
///
/// 提供XBoard相关数据的存储和读取
library;

import 'dart:convert';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/infrastructure/infrastructure.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' as sdk;
import 'package:fl_clash/xboard/domain/domain.dart';

/// XBoard 存储服务
///
/// 负责存储和读取XBoard相关数据，如用户信息、订阅信息等
class XBoardStorageService {
  final StorageInterface _storage;
  
  XBoardStorageService(this._storage);

  // 存储键定义
  static const String _userEmailKey = 'xboard_user_email';
  static const String _userInfoKey = 'xboard_user_info';  // 保留兼容
  static const String _subscriptionInfoKey = 'xboard_subscription_info';  // 保留兼容
  static const String _domainUserKey = 'xboard_domain_user';  // 新：领域模型
  static const String _domainSubscriptionKey = 'xboard_domain_subscription';  // 新：领域模型
  static const String _tunFirstUseKey = 'xboard_tun_first_use_shown';
  static const String _savedEmailKey = 'xboard_saved_email';
  static const String _savedPasswordKey = 'xboard_saved_password';
  static const String _rememberPasswordKey = 'xboard_remember_password';


  Future<Result<bool>> saveUserEmail(String email) async {
    return await _storage.setString(_userEmailKey, email);
  }

  Future<Result<String?>> getUserEmail() async {
    return await _storage.getString(_userEmailKey);
  }

  Future<Result<bool>> saveDomainUser(DomainUser user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      return await _storage.setString(_domainUserKey, userJson);
    } catch (e, stackTrace) {
      return Result.failure(XBoardStorageException(
        message: '保存领域用户信息失败',
        operation: 'write',
        key: _domainUserKey,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  Future<Result<DomainUser?>> getDomainUser() async {
    final result = await _storage.getString(_domainUserKey);
    return result.when(
      success: (userJson) {
        if (userJson == null) return Result.success(null);
        try {
          final Map<String, dynamic> userMap = jsonDecode(userJson);
          return Result.success(DomainUser.fromJson(userMap));
        } catch (e, stackTrace) {
          return Result.failure(XBoardParseException(
            message: '解析领域用户信息失败',
            dataType: 'DomainUser',
            originalError: e,
            stackTrace: stackTrace,
          ));
        }
      },
      failure: (error) => Result.failure(error),
    );
  }

  // ===== 领域模型：订阅信息 =====

  Future<Result<bool>> saveDomainSubscription(DomainSubscription subscription) async {
    try {
      final subscriptionJson = jsonEncode(subscription.toJson());
      return await _storage.setString(_domainSubscriptionKey, subscriptionJson);
    } catch (e, stackTrace) {
      return Result.failure(XBoardStorageException(
        message: '保存领域订阅信息失败',
        operation: 'write',
        key: _domainSubscriptionKey,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  Future<Result<DomainSubscription?>> getDomainSubscription() async {
    final result = await _storage.getString(_domainSubscriptionKey);
    return result.when(
      success: (subscriptionJson) {
        if (subscriptionJson == null) return Result.success(null);
        try {
          final Map<String, dynamic> subscriptionMap = jsonDecode(subscriptionJson);
          return Result.success(DomainSubscription.fromJson(subscriptionMap));
        } catch (e, stackTrace) {
          return Result.failure(XBoardParseException(
            message: '解析领域订阅信息失败',
            dataType: 'DomainSubscription',
            originalError: e,
            stackTrace: stackTrace,
          ));
        }
      },
      failure: (error) => Result.failure(error),
    );
  }

  // ===== 订阅信息（已移除，使用DomainSubscription代替） =====

  // ===== 认证数据清理 =====

  Future<Result<bool>> clearAuthData() async {
    final results = await Future.wait([
      _storage.remove(_userEmailKey),
      _storage.remove(_userInfoKey),
      _storage.remove(_subscriptionInfoKey),
      _storage.remove(_domainUserKey),  // 清理领域模型
      _storage.remove(_domainSubscriptionKey),  // 清理领域模型
    ]);
    
    final allSuccess = results.every((r) => r.dataOrNull == true);
    return Result.success(allSuccess);
  }

  // ===== TUN 首次使用标记 =====

  Future<Result<bool>> hasTunFirstUseShown() async {
    final result = await _storage.getBool(_tunFirstUseKey);
    return result.map((value) => value ?? false);
  }

  Future<Result<bool>> markTunFirstUseShown() async {
    return await _storage.setBool(_tunFirstUseKey, true);
  }

  // ===== 登录凭据 =====

  Future<Result<bool>> saveCredentials(
    String email,
    String password,
    bool rememberPassword,
  ) async {
    final results = await Future.wait([
      _storage.setString(_savedEmailKey, email),
      _storage.setString(_savedPasswordKey, rememberPassword ? password : ''),
      _storage.setBool(_rememberPasswordKey, rememberPassword),
    ]);
    
    final allSuccess = results.every((r) => r.dataOrNull == true);
    return Result.success(allSuccess);
  }

  Future<Result<Map<String, dynamic>>> getSavedCredentials() async {
    final emailResult = await _storage.getString(_savedEmailKey);
    final passwordResult = await _storage.getString(_savedPasswordKey);
    final rememberResult = await _storage.getBool(_rememberPasswordKey);
    
    return Result.success({
      'email': emailResult.dataOrNull,
      'password': passwordResult.dataOrNull,
      'rememberPassword': rememberResult.dataOrNull ?? false,
    });
  }

  // 便捷方法：获取单个保存的凭据字段
  Future<String?> getSavedEmail() async {
    final result = await _storage.getString(_savedEmailKey);
    return result.dataOrNull;
  }

  Future<String?> getSavedPassword() async {
    final result = await _storage.getString(_savedPasswordKey);
    return result.dataOrNull;
  }

  Future<bool> getRememberPassword() async {
    final result = await _storage.getBool(_rememberPasswordKey);
    return result.dataOrNull ?? false;
  }

  Future<Result<bool>> clearSavedCredentials() async {
    final results = await Future.wait([
      _storage.remove(_savedEmailKey),
      _storage.remove(_savedPasswordKey),
      _storage.remove(_rememberPasswordKey),
    ]);
    
    final allSuccess = results.every((r) => r.dataOrNull == true);
    return Result.success(allSuccess);
  }
}

