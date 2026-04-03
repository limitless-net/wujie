import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/l10n/l10n.dart';

/// 忘记密码弹窗 — 在登录页直接弹出，无需跳转
class ForgotPasswordDialog extends ConsumerStatefulWidget {
  const ForgotPasswordDialog({super.key});

  /// 显示忘记密码弹窗
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  @override
  ConsumerState<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

enum _ResetStep { sendCode, resetPassword }

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _currentStep = _ResetStep.sendCode;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _countdownSeconds = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await XBoardSDK.instance.auth.sendEmailVerifyCode(_emailController.text);
      if (mounted) {
        setState(() => _currentStep = _ResetStep.resetPassword);
        XBoardNotification.showSuccess(AppLocalizations.of(context).verificationCodeSent);
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError(_extractErrorMessage(e.toString(), '发送验证码失败'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      XBoardNotification.showError(AppLocalizations.of(context).passwordMismatch);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await XBoardSDK.instance.auth.forgotPassword(
        _emailController.text,
        _codeController.text,
        _passwordController.text,
      );
      if (!success) throw Exception('重置密码失败');
      if (mounted) {
        XBoardNotification.showSuccess(AppLocalizations.of(context).passwordResetSuccessful);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError(_extractErrorMessage(e.toString(), '密码重置失败'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBackToSendCode() {
    setState(() {
      _currentStep = _ResetStep.sendCode;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                  Icon(Icons.lock_reset_outlined, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    _currentStep == _ResetStep.sendCode
                        ? AppLocalizations.of(context).resetPassword
                        : AppLocalizations.of(context).setNewPassword,
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
            // 内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: _currentStep == _ResetStep.sendCode
                      ? _buildSendCodeStep(colorScheme)
                      : _buildResetPasswordStep(colorScheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendCodeStep(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).enterEmailForReset,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        XBInputField(
          controller: _emailController,
          labelText: AppLocalizations.of(context).emailAddress,
          hintText: AppLocalizations.of(context).pleaseEnterEmail,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          validator: (value) {
            if (value == null || value.isEmpty) return AppLocalizations.of(context).pleaseEnterEmail;
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return AppLocalizations.of(context).pleaseEnterValidEmail;
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isLoading
              ? ElevatedButton(
                  onPressed: null,
                  child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : ElevatedButton(
                  onPressed: _sendVerificationCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    AppLocalizations.of(context).sendVerificationCode,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResetPasswordStep(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).verificationCodeSentTo(_emailController.text),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        XBInputField(
          controller: _codeController,
          labelText: AppLocalizations.of(context).verificationCode,
          hintText: AppLocalizations.of(context).pleaseEnterVerificationCode,
          prefixIcon: Icons.verified_user_outlined,
          keyboardType: TextInputType.number,
          enabled: !_isLoading,
          validator: (value) {
            if (value == null || value.isEmpty) return AppLocalizations.of(context).pleaseEnterVerificationCode;
            if (value.length < 4) return AppLocalizations.of(context).pleaseEnterValidVerificationCode;
            return null;
          },
        ),
        const SizedBox(height: 16),
        XBInputField(
          controller: _passwordController,
          labelText: AppLocalizations.of(context).newPassword,
          hintText: AppLocalizations.of(context).pleaseEnterNewPassword,
          prefixIcon: Icons.lock_outlined,
          obscureText: _obscurePassword,
          enabled: !_isLoading,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return AppLocalizations.of(context).pleaseEnterNewPassword;
            if (value.length < 6) return AppLocalizations.of(context).passwordMinLength;
            return null;
          },
        ),
        const SizedBox(height: 16),
        XBInputField(
          controller: _confirmPasswordController,
          labelText: AppLocalizations.of(context).confirmNewPassword,
          hintText: AppLocalizations.of(context).pleaseConfirmNewPassword,
          prefixIcon: Icons.lock_outlined,
          obscureText: _obscureConfirmPassword,
          enabled: !_isLoading,
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return AppLocalizations.of(context).pleaseConfirmNewPassword;
            if (value != _passwordController.text) return AppLocalizations.of(context).passwordMismatch;
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isLoading
              ? ElevatedButton(
                  onPressed: null,
                  child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : ElevatedButton(
                  onPressed: _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    AppLocalizations.of(context).resetPassword,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: (_isLoading || _countdownSeconds > 0) ? null : _goBackToSendCode,
          child: Text(
            _countdownSeconds > 0
                ? '重新发送验证码 (${_countdownSeconds}s)'
                : AppLocalizations.of(context).resendVerificationCode,
            style: TextStyle(color: (_countdownSeconds > 0) ? colorScheme.onSurfaceVariant : colorScheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
