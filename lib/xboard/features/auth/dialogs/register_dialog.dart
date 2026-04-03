import 'dart:async';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show ConfigModel;

/// 注册弹窗 — 在登录页直接弹出，无需跳转
class RegisterDialog extends ConsumerStatefulWidget {
  const RegisterDialog({super.key});

  /// 显示注册弹窗
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const RegisterDialog(),
    );
  }

  @override
  ConsumerState<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends ConsumerState<RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _emailCodeController = TextEditingController();
  bool _isRegistering = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSendingEmailCode = false;
  int _countdownSeconds = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    _emailCodeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final configAsync = ref.read(configProvider);
    final config = configAsync.value;
    final isInviteForce = config?.isInviteForce ?? false;
    final isEmailVerify = config?.isEmailVerify ?? false;

    if (isInviteForce && _inviteCodeController.text.trim().isEmpty) {
      _showInviteCodeAlert();
      return;
    }

    if (isEmailVerify && _emailCodeController.text.trim().isEmpty) {
      XBoardNotification.showError('请输入邮箱验证码');
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isRegistering = true);
      try {
        final success = await XBoardSDK.instance.auth.register(
          _emailController.text,
          _passwordController.text,
          inviteCode: _inviteCodeController.text.trim().isNotEmpty
              ? _inviteCodeController.text
              : null,
          emailCode: isEmailVerify && _emailCodeController.text.trim().isNotEmpty
              ? _emailCodeController.text
              : null,
        );

        if (!success) throw Exception('注册失败');

        if (mounted) {
          final storageService = ref.read(storageServiceProvider);
          await storageService.saveCredentials(
            _emailController.text,
            _passwordController.text,
            true,
          );

          // 注册成功后自动登录
          final userNotifier = ref.read(xboardUserProvider.notifier);
          final loginSuccess = await userNotifier.login(
            _emailController.text,
            _passwordController.text,
          );

          if (mounted) {
            if (loginSuccess) {
              XBoardNotification.showSuccess(appLocalizations.xboardRegisterSuccess);
              Navigator.of(context).pop(true);
            } else {
              // 登录失败仍然关闭弹窗，用户可手动登录
              XBoardNotification.showSuccess(appLocalizations.xboardRegisterSuccess);
              Navigator.of(context).pop(true);
            }
          }
        }
      } catch (e) {
        if (mounted) {
          var errorMessage = _extractErrorMessage(e.toString(), '注册失败');
          if (errorMessage.contains('遇到了些问题') || errorMessage.contains('500')) {
            errorMessage = appLocalizations.inviteCodeIncorrect;
          }
          XBoardNotification.showError(errorMessage);
        }
      } finally {
        if (mounted) setState(() => _isRegistering = false);
      }
    }
  }

  Future<void> _sendEmailCode() async {
    if (_emailController.text.isEmpty) {
      XBoardNotification.showError(appLocalizations.pleaseEnterEmailAddress);
      return;
    }
    if (!_emailController.text.contains('@')) {
      XBoardNotification.showError(appLocalizations.pleaseEnterValidEmailAddress);
      return;
    }
    setState(() => _isSendingEmailCode = true);
    try {
      await XBoardSDK.instance.auth.sendEmailVerifyCode(_emailController.text);
      if (mounted) {
        XBoardNotification.showSuccess(appLocalizations.verificationCodeSentCheckEmail);
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        final msg = _extractErrorMessage(e.toString(), '发送验证码失败');
        XBoardNotification.showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isSendingEmailCode = false);
    }
  }

  void _startCountdown() {
    _countdownSeconds = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) timer.cancel();
      });
    });
  }

  String _extractErrorMessage(String errorStr, String fallback) {
    if (errorStr.contains('XBoardException')) {
      if (errorStr.contains('): ')) {
        final parts = errorStr.split('): ');
        if (parts.length > 1) return parts.sublist(1).join('): ').trim();
      } else if (errorStr.contains('XBoardException: ')) {
        return errorStr.split('XBoardException: ').last.trim();
      }
    }
    var msg = errorStr;
    if (msg.startsWith('Exception: ')) msg = msg.substring(11);
    if (msg.startsWith('Error: ')) msg = msg.substring(7);
    return msg.isEmpty ? fallback : msg;
  }

  void _showInviteCodeAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appLocalizations.inviteCodeRequired),
        content: Text(appLocalizations.inviteCodeRequiredMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appLocalizations.iUnderstand),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final configAsync = ref.watch(configProvider);

    return configAsync.when(
      loading: () => _buildShell(
        colorScheme,
        const Center(child: CircularProgressIndicator()),
        null,
      ),
      error: (_, __) => _buildContent(colorScheme, null),
      data: (config) => _buildContent(colorScheme, config),
    );
  }

  Widget _buildShell(ColorScheme colorScheme, Widget body, ConfigModel? config) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.person_add_outlined, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    appLocalizations.createAccount,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, ConfigModel? config) {
    return _buildShell(
      colorScheme,
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                appLocalizations.fillInfoToRegister,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              XBInputField(
                controller: _emailController,
                labelText: appLocalizations.emailAddress,
                hintText: appLocalizations.pleaseEnterYourEmailAddress,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return appLocalizations.pleaseEnterEmailAddress;
                  if (!value.contains('@')) return appLocalizations.pleaseEnterValidEmailAddress;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              XBInputField(
                controller: _passwordController,
                labelText: appLocalizations.password,
                hintText: appLocalizations.pleaseEnterAtLeast8CharsPassword,
                prefixIcon: Icons.lock_outlined,
                obscureText: !_isPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return appLocalizations.pleaseEnterPassword;
                  if (value.length < 8) return appLocalizations.passwordMin8Chars;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              XBInputField(
                controller: _confirmPasswordController,
                labelText: appLocalizations.confirmNewPassword,
                hintText: appLocalizations.pleaseReEnterPassword,
                prefixIcon: Icons.lock_outlined,
                obscureText: !_isConfirmPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return appLocalizations.pleaseConfirmPassword;
                  if (value != _passwordController.text) return appLocalizations.passwordsDoNotMatch;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 邮箱验证码字段
              if (config?.isEmailVerify == true) ...[
                XBInputField(
                  controller: _emailCodeController,
                  labelText: appLocalizations.emailVerificationCode,
                  hintText: appLocalizations.pleaseEnterEmailVerificationCode,
                  prefixIcon: Icons.verified_user_outlined,
                  keyboardType: TextInputType.number,
                  suffixIcon: _isSendingEmailCode
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(
                          onPressed: _countdownSeconds > 0 ? null : _sendEmailCode,
                          child: Text(_countdownSeconds > 0
                              ? '${_countdownSeconds}s'
                              : appLocalizations.sendVerificationCode),
                        ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return appLocalizations.pleaseEnterEmailVerificationCode;
                    if (value.length != 6) return appLocalizations.verificationCode6Digits;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              // 邀请码
              XBInputField(
                controller: _inviteCodeController,
                labelText: (config?.isInviteForce ?? false)
                    ? '${appLocalizations.xboardInviteCode} *'
                    : appLocalizations.inviteCodeOptional,
                hintText: appLocalizations.pleaseEnterInviteCode,
                prefixIcon: Icons.card_giftcard_outlined,
                enabled: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _isRegistering
                    ? ElevatedButton(
                        onPressed: null,
                        child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          appLocalizations.registerAccount,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      config,
    );
  }
}
