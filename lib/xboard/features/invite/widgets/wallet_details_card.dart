import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/invite/widgets/stat_item_widget.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/transfer_dialog.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/withdraw_dialog.dart';

class WalletDetailsCard extends ConsumerWidget {
  const WalletDetailsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteState = ref.watch(inviteProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  appLocalizations.walletDetails,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showWithdrawDialog(context),
                      icon: const Icon(Icons.account_balance),
                      label: const Text('提现'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showTransferDialog(context),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(appLocalizations.transfer),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (inviteState.isLoading && !inviteState.hasInviteData)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: StatItemWidget(
                      title: appLocalizations.availableCommission,
                      value: inviteState.formattedAvailableCommission,
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                  Expanded(
                    child: StatItemWidget(
                      title: appLocalizations.pendingCommission,
                      value: inviteState.formattedPendingCommission,
                      icon: Icons.hourglass_empty,
                    ),
                  ),
                  Expanded(
                    child: StatItemWidget(
                      title: appLocalizations.walletBalance,
                      value: inviteState.formattedWalletBalance, 
                      icon: Icons.account_balance,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TransferDialog(),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const WithdrawDialog(),
    );
  }
}