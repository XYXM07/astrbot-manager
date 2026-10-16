import 'dart:io';

import 'package:astrbot_manager/l10n.dart';
import 'package:astrbot_manager/models/config.dart';
import 'package:astrbot_manager/screens/main_shell.dart';
import 'package:astrbot_manager/state/app_state.dart';
import 'package:astrbot_manager/state/shell_tabs.dart';
import 'package:astrbot_manager/widgets/navigation_dock.dart';
import 'package:astrbot_manager/widgets/motion.dart';
import 'package:astrbot_manager/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/fake_webview.dart';

void main() {
  testWidgets('dock fits a narrow phone and retargets its moving capsule',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    L10n.lang = 'en';
    addTearDown(() => L10n.lang = 'zh');
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (context, value, _) => FrostedNavigationDock(
              index: value,
              blurEnabled: false,
              onSelected: (value) => index.value = value)),
    )));
    final selection = find.byKey(const ValueKey('dock-selection'));
    final surface = find.byKey(const ValueKey('navigation-dock-surface'));
    expect(tester.getSize(surface).width, 280);
    expect(tester.getTopLeft(surface).dx, 40);
    final start = tester.getTopLeft(selection).dx;
    await tester.tap(find.text('Files'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final moving = tester.getTopLeft(selection).dx;
    expect(moving, greaterThan(start));
    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(tester.getTopLeft(selection).dx, closeTo(moving, 0.01));
    await tester.pumpAndSettle();
    expect(index.value, 3);
    expect(tester.getTopLeft(selection).dx, greaterThan(moving));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dock uses translucent glass in both color modes',
      (tester) async {
    addTearDown(() => AppColors.light = false);
    for (final light in [false, true]) {
      AppColors.light = light;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        bottomNavigationBar: FrostedNavigationDock(
            index: 0, onSelected: (_) {}, blurEnabled: false),
      )));
      final surface = find.byKey(const ValueKey('navigation-dock-surface'));
      final fill = tester
          .widgetList<Container>(
              find.descendant(of: surface, matching: find.byType(Container)))
          .firstWhere((widget) =>
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color != null);
      expect((fill.decoration as BoxDecoration).color!.a, lessThan(0.4));
    }
  });

  testWidgets('navigation stays interactive around an open and closed WebUI',
      (tester) async {
    final platform = FakeWebPlatform();
    WebViewPlatform.instance = platform;
    final app = ShellTestState()..config = ServerConfig.defaults();
    ShellTabs.index.value = 2;
    addTearDown(() {
      ShellTabs.index.value = 0;
      app.dispose();
    });
    app.openCustomWebui('https://example.test');
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pumpAndSettle();
    platform.controllers.single.delegate!.finished
        ?.call('https://example.test');
    await tester.pump();
    expect(find.byKey(const ValueKey('webview-surface')), findsOneWidget);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(ShellTabs.index.value, 3);
    expect(find.text('背景'), findsOneWidget);
    await tester.tap(find.text('仪表盘'));
    await tester.pumpAndSettle();
    expect(ShellTabs.index.value, 0);
    await tester.tap(find.text('WebUI').last);
    await tester.pumpAndSettle();
    expect(platform.controllers.length, 1);
    expect(find.byKey(const ValueKey('webview-surface')), findsOneWidget);
    await app.closeWebuiSession(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('webview-surface')), findsNothing);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(ShellTabs.index.value, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('content fills and receives taps beside the floating dock',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final platform = FakeWebPlatform();
    WebViewPlatform.instance = platform;
    final app = ShellTestState()..config = ServerConfig.defaults();
    ShellTabs.index.value = 2;
    addTearDown(() {
      ShellTabs.index.value = 0;
      app.dispose();
    });
    app.openCustomWebui('https://example.test');
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pumpAndSettle();
    final webview = find.byKey(const ValueKey('webview-surface'));
    final dock = find.byKey(const ValueKey('navigation-dock-surface'));
    final dockRect = tester.getRect(dock);
    expect(tester.getBottomRight(webview).dy, 780);
    final webRender = tester.renderObject(webview);
    for (final x in [10.0, 350.0]) {
      final point = Offset(x, dockRect.center.dy);
      final hits = tester.hitTestOnBinding(point).path;
      expect(hits.any((entry) => entry.target == webRender), isTrue);
    }
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    final list = find
        .descendant(
            of: find.byKey(const ValueKey(3)), matching: find.byType(ListView))
        .first;
    expect(tester.getBottomRight(list).dy, 780);
    expect((tester.widget<ListView>(list).padding! as EdgeInsets).bottom,
        greaterThanOrEqualTo(126));
    // Scroll the final controls above the floating dock instead of cutting off
    // the whole viewport at its top edge.
    final scrollable =
        find.descendant(of: list, matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.text('检查更新')).dy, lessThan(dockRect.top));
    await tester.tap(find.text('文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    for (final action in ['复制', '移动', '删除', '取消']) {
      expect(
          tester.getBottomRight(find.text(action)).dy, lessThan(dockRect.top));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changing a custom background shares one fixed scene with WebUI',
      (tester) async {
    final platform = FakeWebPlatform();
    WebViewPlatform.instance = platform;
    final app = ShellTestState()..config = ServerConfig.defaults();
    ShellTabs.index.value = 3;
    addTearDown(() {
      ShellTabs.index.value = 0;
      app.dispose();
    });
    app.openCustomWebui('https://example.test');
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(home: MainShell()),
    ));
    await tester.pumpAndSettle();
    final scene =
        find.byKey(const ValueKey('shared-background'), skipOffstage: false);
    expect(scene, findsOneWidget);
    final sceneElement = scene.evaluate().single;
    for (final path in [
      'assets/services/astrbot.png',
      'assets/services/napcat.png'
    ]) {
      app.changeBackground(File(path).absolute.path);
      await tester.pumpAndSettle();
      final images = find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is FileImage,
          skipOffstage: false);
      expect(images, findsOneWidget);
      expect((tester.widget<Image>(images).image as FileImage).file.path,
          File(path).absolute.path);
      expect(find.byType(ImageFiltered), findsOneWidget);
      for (final target in [2, 0, 2, 3]) {
        ShellTabs.index.value = target;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(scene, findsOneWidget);
        expect(scene.evaluate().single, same(sceneElement));
        expect(tester.getTopLeft(scene), Offset.zero);
        expect(
            find.ancestor(of: scene, matching: find.byType(MotionIndexedStack)),
            findsNothing);
        final webview = find.byKey(const ValueKey('webview-surface'));
        if (webview.evaluate().isNotEmpty) {
          expect(
              find.ancestor(of: webview, matching: find.byType(ImageFiltered)),
              findsNothing);
          expect(
              find.ancestor(of: webview, matching: find.byType(BackdropFilter)),
              findsNothing);
        }
        await tester.pumpAndSettle();
      }
    }
    expect(platform.controllers.length, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class ShellTestState extends AppState {
  void changeBackground(String path) {
    settings = settings.copyWith(backgroundImagePath: path, blurEnabled: true);
    notifyListeners();
  }

  @override
  Future<void> refreshAll() async {}
}
