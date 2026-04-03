import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/models/models.dart';

/// 公告仓储接口
abstract class NoticeRepository {
  /// 获取公告列表
  Future<Result<List<DomainNotice>>> getNotices();
}
