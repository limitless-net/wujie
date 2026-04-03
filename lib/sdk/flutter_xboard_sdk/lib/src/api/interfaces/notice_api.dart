import '../models/notice_model.dart';

abstract class NoticeApi {
  Future<List<NoticeModel>> getNotices({int page = 1, int pageSize = 10});
  Future<List<NoticeModel>> getGuestNotices({int page = 1, int pageSize = 10});
}
