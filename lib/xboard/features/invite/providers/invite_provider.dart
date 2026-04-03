import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/invite_state.dart';
import 'package:fl_clash/xboard/adapter/state/user_state.dart';

// 初始化文件级日志器
final _logger = FileLogger('invite_provider.dart');

class InviteState {
  final DomainInvite? inviteData;
  final List<DomainCommission> commissionHistory;
  final DomainUser? userInfo;
  final bool isLoading;
  final bool isGenerating;
  final bool isLoadingHistory;
  final String? errorMessage;
  final int currentHistoryPage;
  final bool hasMoreHistory;
  final int historyPageSize;

  const InviteState({
    this.inviteData,
    this.commissionHistory = const [],
    this.userInfo,
    this.isLoading = false,
    this.isGenerating = false,
    this.isLoadingHistory = false,
    this.errorMessage,
    this.currentHistoryPage = 1,
    this.hasMoreHistory = true,
    this.historyPageSize = 10,
  });

  InviteState copyWith({
    DomainInvite? inviteData,
    List<DomainCommission>? commissionHistory,
    DomainUser? userInfo,
    bool? isLoading,
    bool? isGenerating,
    bool? isLoadingHistory,
    String? errorMessage,
    int? currentHistoryPage,
    bool? hasMoreHistory,
    int? historyPageSize,
  }) {
    return InviteState(
      inviteData: inviteData ?? this.inviteData,
      commissionHistory: commissionHistory ?? this.commissionHistory,
      userInfo: userInfo ?? this.userInfo,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      errorMessage: errorMessage,
      currentHistoryPage: currentHistoryPage ?? this.currentHistoryPage,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      historyPageSize: historyPageSize ?? this.historyPageSize,
    );
  }

  bool get hasInviteData => inviteData != null;
  bool get hasActiveCodes => inviteData?.codes.any((code) => code.isAvailable) ?? false;
  int get totalInvites => inviteData?.stats.invitedCount ?? 0;
  double get totalCommission => inviteData?.stats.totalCommission ?? 0.0;
  double get pendingCommission => inviteData?.stats.pendingCommission ?? 0.0;
  double get commissionRate => inviteData?.stats.commissionRate ?? 0.0;
  double get availableCommission => inviteData?.stats.availableCommission ?? 0.0;
  double get walletBalance => (userInfo?.balanceInCents ?? 0) / 100.0;
  String get formattedCommission => _formatCommissionAmount(totalCommission);
  String get formattedPendingCommission => _formatCommissionAmount(pendingCommission);
  String get formattedAvailableCommission => _formatCommissionAmount(availableCommission);
  String get formattedWalletBalance => _formatCommissionAmount(walletBalance);

  String _formatCommissionAmount(double amount) {
    final value = amount;
    if (value >= 1000) {
      return '¥${(value / 1000).toStringAsFixed(1)}k';
    } else {
      return '¥${value.toStringAsFixed(2)}';
    }
  }
}

class InviteNotifier extends Notifier<InviteState> {
  @override
  InviteState build() {
    return const InviteState();
  }

  Future<void> loadInviteData() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      _logger.info('加载邀请信息...');
      _logger.info('加载邀请信息...');
      final inviteInfoModel = await ref.read(getInviteInfoProvider.future);
      final inviteData = _mapInviteInfo(inviteInfoModel);

      state = state.copyWith(
        inviteData: inviteData,
        isLoading: false,
      );

      _logger.info('邀请信息加载成功');
    } catch (e) {
      _logger.info('加载邀请信息失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadCommissionHistory({int page = 1, bool append = false}) async {
    if (state.isLoadingHistory) return;

    state = state.copyWith(isLoadingHistory: true);

    try {
      _logger.info('加载佣金历史... 页码: $page');
      _logger.info('加载佣金历史... 页码: $page');
      final commissionList = await ref.read(getCommissionDetailsProvider(page: page).future);
      final newHistory = commissionList.map(_mapCommission).toList();


      List<DomainCommission> updatedHistory;
      if (append && newHistory.isNotEmpty) {
        // 追加到现有列表
        updatedHistory = [...state.commissionHistory, ...newHistory];
      } else {
        // 替换整个列表
        updatedHistory = newHistory;
      }

      state = state.copyWith(
        commissionHistory: updatedHistory,
        currentHistoryPage: page,
        hasMoreHistory: newHistory.length >= state.historyPageSize,
        isLoadingHistory: false,
      );

      _logger.info('佣金历史加载成功: 第$page页，${newHistory.length} 条记录');
    } catch (e) {
      _logger.info('加载佣金历史失败: $e');
      state = state.copyWith(isLoadingHistory: false);
    }
  }
  
  Future<void> loadNextHistoryPage() async {
    if (!state.hasMoreHistory || state.isLoadingHistory) return;
    await loadCommissionHistory(page: state.currentHistoryPage + 1, append: true);
  }
  
  Future<void> refreshCommissionHistory() async {
    await loadCommissionHistory(page: 1, append: false);
  }

  Future<void> loadUserInfo() async {
    try {
      _logger.info('加载用户信息...');
      _logger.info('加载用户信息...');
      final userModel = await ref.read(getUserInfoProvider.future);
      final userInfo = _mapUser(userModel);
      state = state.copyWith(userInfo: userInfo);
      _logger.info('用户信息加载成功: 钱包余额 ¥${(userInfo?.balanceInCents ?? 0) / 100.0}');
    } catch (e) {
      _logger.info('加载用户信息失败: $e');
    }
  }

  Future<DomainInviteCode?> generateInviteCode() async {
    if (state.isGenerating) return null;

    state = state.copyWith(isGenerating: true, errorMessage: null);

    try {
      _logger.info('生成邀请码...');
      _logger.info('生成邀请码...');
      final codeString = await XBoardSDK.instance.invite.generateInviteCode();
      
      // SDK returns String, we need to wrap it or reload data
      // Assuming generateInviteCode returns the code string
      // But DomainInviteCode is an object.
      // We should reload invite data to get the new code in the list.
      // 更新本地状态
      final newInviteCode = DomainInviteCode(
        code: codeString,
        status: 0,
        createdAt: DateTime.now(),
      );
      await loadInviteData();

      state = state.copyWith(isGenerating: false);
      _logger.info('邀请码生成成功: $newInviteCode');
      return newInviteCode;
    } catch (e) {
      _logger.info('生成邀请码失败: $e');
      state = state.copyWith(
        isGenerating: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<bool> withdrawCommission({
    required String withdrawMethod,
    required String withdrawAccount,
  }) async {
    if (state.isLoading) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      _logger.info('提现佣金: 方式=$withdrawMethod, 账号=$withdrawAccount');
      final availableAmount = state.inviteData?.stats.availableCommission ?? 0.0;
      if (availableAmount <= 0) {
        throw Exception('可提现金额不足');
      }

      final success = await XBoardSDK.instance.invite.withdrawCommission(
        amount: availableAmount,
        method: withdrawMethod,
        params: {'account': withdrawAccount},
      );

      if (!success) {
        throw Exception('提现申请失败');
      }

      await loadInviteData();
      await refreshCommissionHistory();

      state = state.copyWith(isLoading: false);
      _logger.info('提现申请提交成功');
      return true;
    } catch (e) {
      _logger.info('提现申请失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> transferCommission(double amount) async {
    if (state.isLoading) return false;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      _logger.info('划转佣金到钱包: ¥$amount');
      final success = await XBoardSDK.instance.invite.transferCommissionToBalance(amount);
      
      if (!success) {
        throw Exception('划转失败');
      }
      
      await Future.wait([
        loadInviteData(),
        loadUserInfo(),
      ]);
      
      state = state.copyWith(isLoading: false);
      _logger.info('划转成功');
      return true;
    } catch (e) {
      _logger.info('划转失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      loadInviteData(),
      refreshCommissionHistory(),
      loadUserInfo(),
    ]);
  }
}

final inviteProvider = NotifierProvider<InviteNotifier, InviteState>(
  InviteNotifier.new,
);

extension InviteHelpers on WidgetRef {
  InviteState get inviteState => read(inviteProvider);
  InviteNotifier get inviteNotifier => read(inviteProvider.notifier);
}

DomainInvite _mapInviteInfo(InviteInfoModel info) {
  return DomainInvite(
    codes: info.codes.map(_mapInviteCode).toList(),
    stats: InviteStats(
      invitedCount: info.totalInvites,
      totalCommission: info.totalCommission / 100.0,
      pendingCommission: info.pendingCommission / 100.0,
      commissionRate: info.commissionRatePercent,  // 已经是百分比，不需要再除以 100
      availableCommission: info.availableCommission / 100.0,
    ),
  );
}

DomainInviteCode _mapInviteCode(InviteCodeModel code) {
  return DomainInviteCode(
    code: code.code,
    status: code.status ? 0 : 1, // true=active(0), false=inactive(1)
    createdAt: code.createdAt,
  );
}

DomainCommission _mapCommission(CommissionDetailModel item) {
  return DomainCommission(
    id: item.id,
    tradeNo: item.tradeNo,
    amount: item.getAmount / 100.0,
    createdAt: item.createdAt,
  );
}

DomainUser _mapUser(UserModel user) {
  return DomainUser(
    email: user.email,
    uuid: user.uuid,
    avatarUrl: user.avatarUrl,
    planId: user.planId,
    transferLimit: user.transferEnable.toInt(),
    uploadedBytes: 0,
    downloadedBytes: 0,
    balanceInCents: (user.balance * 100).toInt(),
    commissionBalanceInCents: (user.commissionBalance * 100).toInt(),
    expiredAt: user.expiredAt,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
    banned: user.banned,
    remindExpire: user.remindExpire,
    remindTraffic: user.remindTraffic,
    discount: user.discount,
    commissionRate: user.commissionRate,
    telegramId: user.telegramId,
  );
}