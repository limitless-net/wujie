import 'package:fl_clash/models/models.dart';

/// Profile 订阅信息服务
///
/// 从订阅链接响应头解析订阅信息并创建 SubscriptionInfo
class ProfileSubscriptionInfoService {
  static const ProfileSubscriptionInfoService _instance = ProfileSubscriptionInfoService._();

  const ProfileSubscriptionInfoService._();

  static ProfileSubscriptionInfoService get instance => _instance;

  /// 获取并创建 SubscriptionInfo
  ///
  /// 从订阅链接的响应头 subscription-userinfo 解析订阅信息
  ///
  /// [subscriptionUserInfo] 订阅头信息字符串，格式：upload=123;download=456;total=789;expire=1234567890
  ///
  /// 返回创建的 SubscriptionInfo，如果没有提供响应头则返回空的 SubscriptionInfo
  Future<SubscriptionInfo> getSubscriptionInfo({
    String? subscriptionUserInfo,
  }) async {
    // 直接解析 subscription-userinfo 响应头
    if (subscriptionUserInfo != null && subscriptionUserInfo.isNotEmpty) {
      return SubscriptionInfo.formHString(subscriptionUserInfo);
    }

    // 没有订阅头信息时返回空的 SubscriptionInfo
    return const SubscriptionInfo();
  }
}