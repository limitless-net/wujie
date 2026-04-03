import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/notice.freezed.dart';
part 'generated/notice.g.dart';

/// 领域层：公告模型
@freezed
class DomainNotice with _$DomainNotice {
  const factory DomainNotice({
    /// 公告 ID
    required int id,
    
    /// 标题
    required String title,
    
    /// 内容
    required String content,
    
    /// 图片 URL列表
    @Default([]) List<String> imageUrls,
    
    /// 标签列表
    @Default([]) List<String> tags,
    
    /// 是否显示
    @Default(true) bool isVisible,
    
    /// 创建时间
    required DateTime createdAt,
    
    /// 更新时间
    DateTime? updatedAt,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainNotice;

  const DomainNotice._();

  factory DomainNotice.fromJson(Map<String, dynamic> json) => 
    _$DomainNoticeFromJson(json);
}

/// DomainNotice 扩展方法
extension DomainNoticeX on DomainNotice {
  /// 是否有图片
  bool get hasImages => imageUrls.isNotEmpty;

  /// 是否为新公告（7天内）
  bool get isNew {
    final now = DateTime.now();
    final diff = now.difference(createdAt).inDays;
    return diff <= 7;
  }
}
