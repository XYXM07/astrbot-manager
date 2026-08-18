import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n.dart';
import 'screens/connection_screen.dart';
import 'screens/main_shell.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AstrbotManagerApp());
}

class AstrbotManagerApp extends StatelessWidget {
  const AstrbotManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: Consumer<AppState>(
        builder: (context, app, _) {
          // 先同步模式与语言，再构建主题（构建时的副作用，配合 watch 触发重建）
          AppColors.light = app.settings.lightMode;
          L10n.lang = app.settings.language == 'en' ? 'en' : 'zh';
          return MaterialApp(
            title: 'astrbot助手',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            // 中文本地化：长按选择/复制粘贴菜单显示中文
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
            locale: Locale(L10n.lang == 'en' ? 'en' : 'zh'),
            home: const _RootGate(),
          );
        },
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.loading) {
      return Scaffold(
        backgroundColor: AppColors.bgTop,
        body: const Center(child: CircularProgressIndicator(color: AppColors.violet)),
      );
    }
    if (app.config == null) return ConnectionScreen();
    return MainShell();
  }
}
