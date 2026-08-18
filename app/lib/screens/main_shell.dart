import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/webui_page.dart';
import '../state/app_state.dart';
import '../state/shell_tabs.dart';
import '../theme.dart';

/// 主框架：底部毛玻璃导航栏 + 三个常驻页面（IndexedStack 保持全部存活）
class MainShell extends StatefulWidget {
  MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    return ValueListenableBuilder<int>(
      valueListenable: ShellTabs.index,
      builder: (context, idx, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: idx,
            children: [
              HomeScreen(),
              WebUiSessionsPage(),
              SettingsScreen(),
            ],
          ),
          bottomNavigationBar: _frostedNavBar(idx, settings.blurSigma, settings.blurEnabled),
        );
      },
    );
  }

  /// 半透明毛玻璃导航栏（跟随"毛玻璃背景模糊"设置：开启则模糊，关闭则纯透明）
  Widget _frostedNavBar(int idx, double sigma, bool blurOn) {
    final bar = Container(
      decoration: BoxDecoration(
        color: AppColors.panelStrong,
        border: Border(
          top: BorderSide(color: AppColors.text.withOpacity(0.10)),
        ),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIndex: idx,
        indicatorColor: AppColors.violet.withOpacity(0.28),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => ShellTabs.index.value = i,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard),
            selectedIcon: Icon(Icons.space_dashboard),
            label: L10n.t('仪表盘'),
          ),
          NavigationDestination(
            icon: Icon(Icons.language),
            selectedIcon: Icon(Icons.language),
            label: 'WebUI',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings),
            label: L10n.t('设置'),
          ),
        ],
      ),
    );
    if (!blurOn) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: bar,
      ),
    );
  }
}
