import 'dart:io';
import 'package:fl_clash/xboard/widgets/navigation/desktop_navigation_rail.dart';
import 'package:fl_clash/xboard/widgets/navigation/mobile_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 适配性的 Shell 布局
/// 桌面端：侧边栏 + 内容区
/// 移动端：底部导航栏 + 内容区
class AdaptiveShellLayout extends ConsumerWidget {
  final StatefulNavigationShell child;

  const AdaptiveShellLayout({
    super.key,
    required this.child,
  });

  void _onDestinationSelected(BuildContext context, int index, bool isDesktop) {
    if (isDesktop) {
      // 桌面端路由：首页、套餐、客服、邀请
      // 使用 context.go() 让 GoRouter 自动切换到对应的分支
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/plans');
          break;
        case 2:
          context.go('/support');
          break;
        case 3:
          context.go('/invite');
          break;
      }
    } else {
      // 移动端路由：首页、邀请
      // 使用 context.go() 切换分支
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/invite');
          break;
      }
    }
  }

  int _getCurrentIndex(BuildContext context, bool isDesktop) {
    final location = GoRouterState.of(context).uri.path;
    
    if (isDesktop) {
      // 桌面端导航栏索引：首页(0)、套餐(1)、客服(2)、邀请(3)
      // 分支索引：0=首页, 1=套餐, 2=客服, 3=邀请
      if (location == '/') return 0;
      if (location.startsWith('/plans')) return 1;
      if (location.startsWith('/support')) return 2;
      if (location.startsWith('/invite')) return 3;
      return 0;
    } else {
      // 移动端导航栏索引：首页(0)、邀请(1)
      // 对应的分支索引：首页=0, 邀请=3
      if (location.startsWith('/invite')) return 1;
      // Plans 和 Support 页面不在移动端底部导航栏中，返回 -1 表示不高亮任何项
      if (location.startsWith('/plans') || location.startsWith('/support')) return -1;
      return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 根据操作系统平台判断设备类型
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final currentIndex = _getCurrentIndex(context, isDesktop);
    
    if (isDesktop) {
      // 桌面端：侧边栏 + 内容区（无外层 Scaffold）
      return Row(
        children: [
          DesktopNavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => _onDestinationSelected(context, index, true),
          ),
          Expanded(
            child: child,
          ),
        ],
      );
    } else {
      // 移动端：Scaffold + 底部导航栏
      // Plans 和 Support 页面不显示底部导航栏
      final location = GoRouterState.of(context).uri.path;
      final hideBottomNav = location.startsWith('/plans') || location.startsWith('/support');
      
      return Scaffold(
        body: child,
        bottomNavigationBar: hideBottomNav 
            ? null 
            : MobileNavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: (index) => _onDestinationSelected(context, index, false),
              ),
      );
    }
  }
}

