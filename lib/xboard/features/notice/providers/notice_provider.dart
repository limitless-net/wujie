import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/notice_state.dart';

/// 公告状态
class NoticeState {
  final List<DomainNotice> notices;
  final bool isLoading;
  final String? error;
  final Set<int> dismissedIndices;

  const NoticeState({
    this.notices = const [],
    this.isLoading = false,
    this.error,
    this.dismissedIndices = const {},
  });

  /// 获取可见的公告列表（未被关闭的）
  List<DomainNotice> get visibleNotices {
    return notices
        .asMap()
        .entries
        .where((entry) => !dismissedIndices.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
  }

  NoticeState copyWith({
    List<DomainNotice>? notices,
    bool? isLoading,
    String? error,
    Set<int>? dismissedIndices,
  }) {
    return NoticeState(
      notices: notices ?? this.notices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      dismissedIndices: dismissedIndices ?? this.dismissedIndices,
    );
  }
}

/// 公告Provider
class NoticeNotifier extends StateNotifier<NoticeState> {
  NoticeNotifier(this._ref) : super(const NoticeState());

  final Ref _ref;

  /// 获取公告列表
  Future<void> fetchNotices() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final noticeModels = await _ref.read(getNoticesProvider.future);
      final notices = noticeModels.map(_mapNotice).toList();
      state = state.copyWith(
        notices: notices,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 标记公告为已读
  void markAsRead(int index) {
    // 实现公告已读逻辑（可选）
  }

  /// 关闭公告横幅
  void dismissBanner(int index) {
    final newDismissed = Set<int>.from(state.dismissedIndices)..add(index);
    state = state.copyWith(dismissedIndices: newDismissed);
  }
}

/// 公告Provider实例
final noticeProvider = StateNotifierProvider<NoticeNotifier, NoticeState>((ref) {
  return NoticeNotifier(ref);
});

DomainNotice _mapNotice(NoticeModel notice) {
  return DomainNotice(
    id: notice.id,
    title: notice.title,
    content: notice.content,
    imageUrls: notice.imgUrl != null && notice.imgUrl!.isNotEmpty ? [notice.imgUrl!] : [],
    tags: notice.tags ?? [],
    isVisible: notice.show,
    createdAt: DateTime.fromMillisecondsSinceEpoch(notice.createdAt * 1000),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(notice.updatedAt * 1000),
  );
}

