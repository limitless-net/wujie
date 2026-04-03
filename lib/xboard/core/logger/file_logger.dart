import 'logger.dart';

/// 文件级日志工具类
/// 
/// 每个文件在顶部初始化一次，之后直接使用，自动带文件名标签
/// 
/// 使用示例：
/// ```dart
/// // 在文件顶部初始化
/// final _logger = FileLogger('auto_latency_service.dart');
/// 
/// // 之后直接使用
/// void someFunction() {
///   _logger.info('这是一条日志');  // 输出: [XBoard][时间][INFO] [auto_latency_service.dart] 这是一条日志
///   _logger.error('发生错误', exception);
/// }
/// ```
class FileLogger {
  final String fileName;
  
  /// 创建文件级日志器
  /// 
  /// [fileName] 文件名，建议使用文件的真实名称，如 'auto_latency_service.dart'
  const FileLogger(this.fileName);
  
  /// 调试级别日志
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    XBoardLogger.debug('[$fileName] $message', error, stackTrace);
  }
  
  /// 信息级别日志
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    XBoardLogger.info('[$fileName] $message', error, stackTrace);
  }
  
  /// 警告级别日志
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    XBoardLogger.warning('[$fileName] $message', error, stackTrace);
  }
  
  /// 错误级别日志
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    XBoardLogger.error('[$fileName] $message', error, stackTrace);
  }
}

