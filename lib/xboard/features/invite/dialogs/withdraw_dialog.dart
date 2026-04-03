import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';

class WithdrawDialog extends ConsumerStatefulWidget {
  const WithdrawDialog({super.key});

  @override
  ConsumerState<WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends ConsumerState<WithdrawDialog> {
  final TextEditingController _accountController = TextEditingController();
  bool _isWithdrawing = false;
  bool _isSuccess = false;
  
  // 提现方式列表
  // TODO: 未来可以通过 SystemConfig API 从后端获取: config.withdrawMethods
  // 接口: /api/v1/user/comm/config -> SystemConfig.withdrawMethods
  final List<String> _withdrawMethods = ['支付宝', '微信', '银行卡', 'PayPal', 'USDT'];
  String? _selectedMethod;

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.read(inviteProvider);
    final double availableAmount = inviteState.availableCommission;  // 已经是元，不需要再除以100

    return AlertDialog(
      title: Text(appLocalizations.withdrawCommission),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSuccess
                ? const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Colors.green,
                    key: ValueKey('success'),
                  )
                : _isWithdrawing
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          key: ValueKey('loading'),
                        ),
                      )
                    : const Icon(
                        Icons.account_balance_wallet,
                        size: 48,
                        color: Colors.blue,
                        key: ValueKey('wallet'),
                      ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSuccess
                ? Text(
                    '提现申请已提交',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    key: const ValueKey('success-text'),
                  )
                : _isWithdrawing
                    ? Text(
                        '提交中...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        key: const ValueKey('loading-text'),
                      )
                    : Text(
                        '可提现金额：¥${availableAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        key: const ValueKey('balance-text'),
                      ),
          ),
          const SizedBox(height: 16),
          if (!_isWithdrawing && !_isSuccess) ...[
            DropdownButtonFormField<String>(
              value: _selectedMethod,
              decoration: InputDecoration(
                labelText: '提现方式',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payment),
              ),
              items: _withdrawMethods.map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMethod = newValue;
                });
              },
              hint: const Text('请选择提现方式'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountController,
              decoration: InputDecoration(
                labelText: '提现账号',
                hintText: '请输入您的账号',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.account_box),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '提现申请将通过工单系统提交，请等待管理员审核',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (!_isWithdrawing && !_isSuccess) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appLocalizations.cancel),
          ),
          ElevatedButton(
            onPressed: _performWithdraw,
            child: const Text('提交申请'),
          ),
        ],
      ],
    );
  }

  Future<void> _performWithdraw() async {
    if (_selectedMethod == null || _selectedMethod!.isEmpty) {
      if (mounted) {
        XBoardNotification.showError('请选择提现方式');
      }
      return;
    }
    
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      if (mounted) {
        XBoardNotification.showError('请输入提现账号');
      }
      return;
    }
    
    setState(() {
      _isWithdrawing = true;
    });
    
    try {
      final result = await ref.read(inviteProvider.notifier).withdrawCommission(
        withdrawMethod: _selectedMethod!,
        withdrawAccount: account,
      );
      
      if (mounted) {
        setState(() {
          _isWithdrawing = false;
          _isSuccess = result;
        });
        
        if (result) {
          // 成功后显示动画，然后自动关闭
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            // 关闭后显示提示
            Future.microtask(() {
              if (mounted) {
                XBoardNotification.showSuccess('提现申请已提交，请等待审核');
              }
            });
          }
        } else {
          XBoardNotification.showError('提交失败');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWithdrawing = false;
          _isSuccess = false;
        });
        XBoardNotification.showError('提交失败：$e');
      }
    }
  }
}