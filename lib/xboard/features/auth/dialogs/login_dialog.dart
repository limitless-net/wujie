import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/xboard/features/auth/dialogs/register_dialog.dart';
import 'package:fl_clash/xboard/features/auth/dialogs/forgot_password_dialog.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/config/utils/config_file_loader.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 登录弹窗 — 居中弹出式对话框
class LoginDialog extends ConsumerStatefulWidget {
  const LoginDialog({super.key});

  /// 显示登录弹窗，返回 true 表示登录成功
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const LoginDialog(),
    );
  }

  @override
  ConsumerState<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberPassword = false;
  bool _isPasswordVisible = false;
  bool _isLoggingIn = false;
  String _appTitle = '';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _loadAppInfo();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAppInfo() async {
    final title = await ConfigFileLoaderHelper.getAppTitle();
    if (mounted) setState(() => _appTitle = title);
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final storageService = ref.read(storageServiceProvider);
      final savedEmail = await storageService.getSavedEmail();
      final savedPassword = await storageService.getSavedPassword();
      final rememberPassword = await storageService.getRememberPassword();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
      if (savedPassword != null && savedPassword.isNotEmpty && rememberPassword) {
        _passwordController.text = savedPassword;
      }
      _rememberPassword = rememberPassword;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoggingIn = true);
    try {
      final userNotifier = ref.read(xboardUserProvider.notifier);
      final success = await userNotifier.login(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        final storageService = ref.read(storageServiceProvider);
        if (_rememberPassword) {
          await storageService.saveCredentials(
            _emailController.text,
            _passwordController.text,
            true,
          );
        } else {
          await storageService.saveCredentials(
            _emailController.text,
            '',
            false,
          );
        }
        if (mounted) {
          XBoardNotification.showSuccess(appLocalizations.xboardLoginSuccess);
          Navigator.of(context).pop(true);
        }
      } else {
        final userState = ref.read(xboardUserProvider);
        if (userState.errorMessage != null) {
          XBoardNotification.showError(userState.errorMessage!);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _navigateToRegister() async {
    Navigator.of(context).pop();
    final result = await RegisterDialog.show(context);
    // 注册成功等同于登录成功（不需要额外处理，register dialog 已保存凭据）
    if (result == true) {
      // 注册成功
    }
  }

  void _navigateToForgotPassword() async {
    Navigator.of(context).pop();
    await ForgotPasswordDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initState = ref.watch(initializationProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom > 0
              ? 16
              : 0,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo + 标题
                Center(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/icon.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _appTitle,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '登录以使用完整功能',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // 邮箱输入
                XBInputField(
                  controller: _emailController,
                  labelText: appLocalizations.xboardEmail,
                  hintText: appLocalizations.xboardEmail,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.xboardEmail;
                    }
                    if (!value.contains('@')) {
                      return appLocalizations.xboardEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // 密码输入
                XBInputField(
                  controller: _passwordController,
                  labelText: appLocalizations.xboardPassword,
                  hintText: appLocalizations.xboardPassword,
                  prefixIcon: Icons.lock_outlined,
                  obscureText: !_isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.xboardPassword;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // 记住密码
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberPassword,
                        onChanged: (value) {
                          setState(() => _rememberPassword = value ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() => _rememberPassword = !_rememberPassword);
                      },
                      child: Text(
                        appLocalizations.xboardRememberPassword,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 登录按钮
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: initState.isReady && !_isLoggingIn ? _login : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            appLocalizations.xboardLogin,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                // 初始化失败重试
                if (initState.isFailed) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(initializationProvider.notifier).refresh();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(
                        '连接失败，点击重试',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // 底部链接
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _navigateToForgotPassword,
                      child: Text(appLocalizations.xboardForgotPassword),
                    ),
                    TextButton(
                      onPressed: _navigateToRegister,
                      child: Text(
                        appLocalizations.xboardRegister,
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
