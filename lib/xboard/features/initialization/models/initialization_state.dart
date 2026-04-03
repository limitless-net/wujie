import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/initialization_state.freezed.dart';

/// XBoard 初始化状态枚举
enum InitializationStatus {
  /// 未开始
  idle,
  
  /// 检查域名中
  checkingDomain,
  
  /// 初始化 SDK 中
  initializingSDK,
  
  /// 就绪
  ready,
  
  /// 失败
  failed,
}

/// XBoard 初始化状态
@freezed
class InitializationState with _$InitializationState {
  const factory InitializationState({
    /// 当前状态
    @Default(InitializationStatus.idle) InitializationStatus status,
    
    /// 当前使用的域名
    String? currentDomain,
    
    /// 错误信息
    String? errorMessage,
    
    /// 域名延迟（毫秒）
    int? latency,
    
    /// 最后检查时间
    DateTime? lastChecked,
    
    /// 当前步骤描述
    String? currentStepDescription,
  }) = _InitializationState;
  
  const InitializationState._();
  
  /// 是否已就绪
  bool get isReady => status == InitializationStatus.ready;
  
  /// 是否正在初始化
  bool get isInitializing => 
      status == InitializationStatus.checkingDomain || 
      status == InitializationStatus.initializingSDK;
  
  /// 是否失败
  bool get isFailed => status == InitializationStatus.failed;
  
  /// 获取进度百分比（0-100）
  int get progressPercentage {
    switch (status) {
      case InitializationStatus.idle:
        return 0;
      case InitializationStatus.checkingDomain:
        return 30;
      case InitializationStatus.initializingSDK:
        return 70;
      case InitializationStatus.ready:
        return 100;
      case InitializationStatus.failed:
        return 0;
    }
  }
}
