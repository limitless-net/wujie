/// 面板类型枚举
/// 用于区分 XBoard、V2Board 和 XV2B 等不同的后端实现
enum PanelType {
  /// XBoard 面板
  xboard('xboard'),

  /// V2Board 面板
  v2board('v2board'),

  /// XV2B 面板 (基于 V2Board，API 兼容)
  xv2b('xv2b');

  const PanelType(this.value);
  
  /// 字符串值
  final String value;

  /// 从字符串创建 PanelType
  static PanelType fromString(String value) {
    return PanelType.values.firstWhere(
      (type) => type.value == value.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown panel type: $value'),
    );
  }

  @override
  String toString() => value;
}
