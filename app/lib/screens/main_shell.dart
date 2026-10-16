import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/navigation_dock.dart';
import '../screens/files_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/webui_page.dart';
import '../state/app_state.dart';
import '../state/shell_tabs.dart';
import '../widgets/background.dart';
import '../widgets/motion.dart';
import '../widgets/shell_layout.dart';

/// 主框架：底部毛玻璃导航栏 + 四个常驻页面，切换时保留页面状态。
class MainShell extends StatefulWidget {
  MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = app.settings;
    final bottomClearance = ShellLayout.dockHeight +
        ShellLayout.dockTopGap +
        (MediaQuery.paddingOf(context).bottom > ShellLayout.dockBottomGap
            ? MediaQuery.paddingOf(context).bottom
            : ShellLayout.dockBottomGap);
    return ValueListenableBuilder<int>(
      valueListenable: ShellTabs.index,
      builder: (context, idx, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GradientBackground(
            child: ShellLayout(
              bottomClearance: bottomClearance,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MotionIndexedStack(
                    index: idx,
                    nativeViewPages: const {2},
                    children: [
                      HomeScreen(),
                      FilesScreen(),
                      WebUiSessionsPage(),
                      SettingsScreen(),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FrostedNavigationDock(
                      index: idx,
                      onSelected: (index) => ShellTabs.index.value = index,
                      // A retained Android WebView may still be on screen
                      // while a tab transition finishes.
                      blurEnabled:
                          settings.blurEnabled && app.webuiSessions.isEmpty,
                      blurSigma: settings.blurSigma,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
