import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/invite/widgets/user_menu_widget.dart';
import 'package:fl_clash/xboard/features/invite/widgets/error_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/invite_rules_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/invite_qr_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/invite_stats_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/wallet_details_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/commission_history_card.dart';

class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> 
    with AutomaticKeepAliveClientMixin {
  bool _hasInitialized = false;
  
  @override
  bool get wantKeepAlive => true;  // 保持页面状态，防止重建
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_hasInitialized) return;
      _hasInitialized = true;
      
      await ref.read(inviteProvider.notifier).refresh();
      final inviteState = ref.read(inviteProvider);
      if (!inviteState.hasInviteData || inviteState.inviteData!.codes.isEmpty) {
        await ref.read(inviteProvider.notifier).generateInviteCode();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // 必须调用，配合 AutomaticKeepAliveClientMixin
    
    final appLocalizations = AppLocalizations.of(context);
    // 根据操作系统平台判断设备类型
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: Text(appLocalizations.invite),
        automaticallyImplyLeading: false,
        actions: const [
          UserMenuWidget(),
        ],
      ),
      body: Consumer(
        builder: (_, ref, __) {
          return RefreshIndicator(
            onRefresh: () => ref.read(inviteProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ErrorCard(),
                  
                  const InviteRulesCard(),
                  const SizedBox(height: 16),
                  
                  const InviteQrCard(),
                  const SizedBox(height: 16),
                  
                  const InviteStatsCard(),
                  const SizedBox(height: 16),
                  
                  const WalletDetailsCard(),
                  const SizedBox(height: 16),
                  
                  const CommissionHistoryCard(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}