import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/hotkey_manager.dart';
import 'package:fl_clash/manager/manager.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'controller.dart';
import 'xboard/xboard.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/router/app_router.dart' as xboard_router;
import 'package:fl_clash/xboard/features/initialization/initialization.dart';

class Application extends ConsumerStatefulWidget {
  const Application({
    super.key,
  });

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateGroupTaskTimer;
  Timer? _autoUpdateProfilesTaskTimer;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CommonPageTransitionsBuilder(),
      TargetPlatform.windows: CommonPageTransitionsBuilder(),
      TargetPlatform.linux: CommonPageTransitionsBuilder(),
      TargetPlatform.macOS: CommonPageTransitionsBuilder(),
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) {
    return ref.read(genColorSchemeProvider(brightness));
  }

  @override
  void initState() {
    super.initState();
    _autoUpdateGroupTask();
    _autoUpdateProfilesTask();
    globalState.appController = AppController(context, ref);
    
    // ✅ 后台预热：统一初始化服务（不阻塞 UI）
    // 这样快速认证和登录页都能使用已初始化的 SDK
    Future.microtask(() async {
      try {
        await ref.read(initializationProvider.notifier).initialize();
      } catch (e) {
        // 初始化失败，登录页会处理
        debugPrint('[Application] 预热初始化失败: $e');
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final currentContext = globalState.navigatorKey.currentContext;
      if (currentContext != null) {
        globalState.appController = AppController(currentContext, ref);
      }
      await globalState.appController.init();
      globalState.appController.initLink();
      app?.initShortcuts();
      
      // ✅ 等待初始化完成后再执行快速认证
      _performQuickAuthWithDomainService();
      
      // 启动后检查更新
      _checkForUpdates();
      
    });
  }

  /// 使用新域名服务架构进行快速认证检查
  void _performQuickAuthWithDomainService() {
    // 等待初始化完成后再检查
    Future.microtask(() async {
      try {
        debugPrint('[Application] 开始快速认证检查...');
        
        // ✅ 等待初始化完成
        final initState = ref.read(initializationProvider);
        if (!initState.isReady) {
          debugPrint('[Application] 等待初始化完成...');
          // 等待初始化完成（最多 30 秒）
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          while (!ref.read(initializationProvider).isReady && 
                 DateTime.now().isBefore(deadline)) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          
          if (!ref.read(initializationProvider).isReady) {
            debugPrint('[Application] 初始化超时，跳过快速认证');
            return;
          }
        }
        
        // SDK 已初始化，执行快速认证
        final userNotifier = ref.read(xboardUserProvider.notifier);
        await userNotifier.quickAuth();
        
        // 强制刷新UI，确保路由能够响应最新的认证状态
        if (mounted) {
          setState(() {});
        }
        
        debugPrint('[Application] 快速认证检查完成');
      } catch (e) {
        debugPrint('[Application] 快速认证检查失败: $e');
        // 即使认证检查失败，也要确保UI能正常显示
        if (mounted) {
          setState(() {});
        }
      }
    });
  }


  /// 检查应用更新
  void _checkForUpdates() {
    // 延迟5秒后检查更新，确保应用完全启动
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        debugPrint('[Application] 开始自动检查更新...');
        final updateNotifier = ref.read(updateCheckProvider.notifier);
        await updateNotifier.checkForUpdates();
        
        // 检查是否有更新
        final updateState = ref.read(updateCheckProvider);
        if (updateState.hasUpdate && mounted) {
          final currentContext = globalState.navigatorKey.currentContext;
          if (currentContext != null) {
            debugPrint('[Application] 发现新版本，显示更新弹窗');
            // 显示更新弹窗
            showDialog(
              context: currentContext,
              barrierDismissible: !updateState.forceUpdate, // 强制更新时不能取消
              builder: (context) => UpdateDialog(state: updateState),
            );
          }
        } else if (updateState.error != null) {
          debugPrint('[Application] 自动更新检查失败，忽略错误: ${updateState.error}');
          // 自动检查失败时静默处理，不打扰用户
        } else {
          debugPrint('[Application] 已是最新版本');
        }
      } catch (e) {
        debugPrint('[Application] 自动更新检查异常: $e');
        // 自动检查异常时静默处理，不影响应用正常使用
      }
    });
  }

  _autoUpdateGroupTask() {
    _autoUpdateGroupTaskTimer = Timer(const Duration(milliseconds: 20000), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        globalState.appController.updateGroupsDebounce();
        _autoUpdateGroupTask();
      });
    });
  }

  _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await globalState.appController.autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  _buildPlatformState(Widget child) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(
            child: ProxyManager(
              child: child,
            ),
          ),
        ),
      );
    }
    return AndroidManager(
      child: TileManager(
        child: child,
      ),
    );
  }

  _buildState(Widget child) {
    return AppStateManager(
      child: ClashManager(
        child: ConnectivityManager(
          onConnectivityChanged: (results) async {
            if (!results.contains(ConnectivityResult.vpn)) {
              await clashCore.closeConnections();
            }
            globalState.appController.updateLocalIp();
            globalState.appController.addCheckIpNumDebounce();
          },
          child: child,
        ),
      ),
    );
  }

  _buildPlatformApp(Widget child) {
    if (system.isDesktop) {
      return WindowHeaderContainer(
        child: child,
      );
    }
    return VpnManager(
      child: child,
    );
  }

  _buildApp(Widget child) {
    return MessageManager(
      child: ThemeManager(
        child: child,
      ),
    );
  }

  @override
  Widget build(context) {
    return _buildPlatformState(
      _buildState(
        Consumer(
          builder: (_, ref, child) {
            // 初始化 WebSocket 自动连接器 - 监听登录状态并自动管理 WebSocket 连接
            // 这个 Provider 会在登录成功时自动连接,登出时自动断开
            ref.watch(webSocketAutoConnectorProvider);

            final locale =
                ref.watch(appSettingProvider.select((state) => state.locale));
            final themeProps = ref.watch(themeSettingProvider);
            final userState = ref.watch(xboardUserProvider);
            
            // 使用 go_router 的路由系统
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate
              ],
              builder: (_, child) {
                return AppEnvManager(
                  child: _buildPlatformApp(
                    _buildApp(child!),
                  ),
                );
              },
              routerConfig: _buildRouter(userState),
              scrollBehavior: BaseScrollBehavior(),
              title: appName,
              locale: utils.getLocaleForString(locale),
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              themeMode: themeProps.themeMode,
              theme: ThemeData(
                useMaterial3: true,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.light,
                  primaryColor: themeProps.primaryColor,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                ).toPureBlack(themeProps.pureBlack),
              ),
            );
          },
        ),
      ),
    );
  }

  // 构建带认证重定向的路由器
  GoRouter _buildRouter(UserAuthState userState) {
    return GoRouter(
      navigatorKey: globalState.navigatorKey,
      initialLocation: '/',
      routes: xboard_router.routes,
      redirect: (context, state) {
        final isAuthenticated = userState.isAuthenticated;
        final isInitialized = userState.isInitialized;
        final isLoginPage = state.uri.path == '/login';

        // 初始化中，显示加载页面
        if (!isInitialized) {
          return '/loading';
        }

        // 未认证且不在登录页，跳转到登录页
        if (!isAuthenticated && !isLoginPage) {
          return '/login';
        }

        // 已认证且在登录页，跳转到首页
        if (isAuthenticated && isLoginPage) {
          return '/';
        }

        return null; // 不重定向
      },
    );
  }

  @override
  Future<void> dispose() async {
    try {
      linkManager.destroy();
      _autoUpdateGroupTaskTimer?.cancel();
      _autoUpdateProfilesTaskTimer?.cancel();
      
      // 释放XBoard SDK资源
      try {
        XBoardSDK.instance.dispose();
      // ignore: empty_catches
      } catch (e) {
      }
      
      await clashCore.destroy();
      await globalState.appController.savePreferences();
      await globalState.appController.handleExit();
      
    // ignore: empty_catches
    } catch (e) {
    }
    
    super.dispose();
  }
}

// ✅ 旧的 _AppHomeRouter 已被 go_router 替代
// go_router 通过 redirect 函数自动处理认证重定向