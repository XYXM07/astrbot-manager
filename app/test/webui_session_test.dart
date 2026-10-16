import 'dart:async';

import 'package:astrbot_manager/models/config.dart';
import 'package:astrbot_manager/services/webui_session.dart';
import 'package:astrbot_manager/state/app_state.dart';
import 'support/fake_webview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  late FakeWebPlatform platform;
  late AppState app;
  setUp(() {
    platform = FakeWebPlatform();
    WebViewPlatform.instance = platform;
    app = AppState();
  });
  tearDown(() => app.dispose());

  WebUiSession direct({WebViewController Function()? factory}) => WebUiSession(
        id: 'test',
        service: ServerConfig.defaults().services.first,
        app: app,
        directUrl: 'https://example.test',
        autoStart: false,
        controllerFactory: factory,
      );

  test('async native configuration failures become a retryable session error',
      () async {
    final controller = WebViewController();
    platform.controllers.single.configureError = StateError('native failure');
    final session = direct(factory: () => controller);
    addTearDown(session.dispose);
    await session.start();
    expect(session.connecting, isFalse);
    expect(session.error, contains('native failure'));
    expect(session.controller, isNull);
    platform.controllers.single.configureError = null;
    await session.start();
    expect(session.error, isNull);
    expect(session.controller, same(controller));
  });

  test('concurrent retries share one initialization and one native view',
      () async {
    final controller = WebViewController();
    final native = platform.controllers.single;
    native.configureGate = Completer<void>();
    var created = 0;
    final session = direct(factory: () {
      created++;
      return controller;
    });
    addTearDown(session.dispose);
    final first = session.start();
    final second = session.start();
    expect(first, same(second));
    native.configureGate!.complete();
    await Future.wait([first, second]);
    expect(created, 1);
    expect(native.loads.length, 1);
  });

  test('closing during configuration prevents loading and late notifications',
      () async {
    final controller = WebViewController();
    final native = platform.controllers.single;
    native.configureGate = Completer<void>();
    final session = direct(factory: () => controller);
    var notifications = 0;
    session.addListener(() => notifications++);
    final starting = session.start();
    await Future<void>.delayed(Duration.zero);
    await session.close();
    session.dispose();
    final before = notifications;
    native.configureGate!.complete();
    await starting;
    expect(native.loads, isEmpty);
    expect(session.controller, isNull);
    expect(notifications, before);
  });

  testWidgets('stalled pages time out and closed callbacks stay inert',
      (tester) async {
    final session = direct();
    addTearDown(session.dispose);
    await session.start();
    final delegate = platform.controllers.single.delegate!;
    expect(session.connecting, isTrue);
    await tester.pump(const Duration(seconds: 31));
    expect(session.connecting, isFalse);
    expect(session.pageError, isNotNull);
    await session.close();
    delegate.finished?.call('https://example.test');
    delegate.started?.call('https://example.test');
    expect(session.controller, isNull);
    expect(session.connecting, isFalse);
  });

  test('async load and reload failures are consumed', () async {
    final controller = WebViewController();
    final native = platform.controllers.single;
    native.loadError = StateError('load failed');
    final session = direct(factory: () => controller);
    addTearDown(session.dispose);
    await session.start();
    expect(session.error, contains('load failed'));
    native.loadError = null;
    await session.start();
    native.reloadError = StateError('reload failed');
    await session.reloadPage();
    expect(session.pageError, contains('reload failed'));
    expect(session.connecting, isFalse);
  });

  test('late tunnel creation is closed after the session is dismissed',
      () async {
    final ssh = PendingTunnelSsh();
    final remoteApp = AppState(ssh: ssh)..config = ServerConfig.defaults();
    addTearDown(remoteApp.dispose);
    final session = WebUiSession(
        id: 'remote',
        service: remoteApp.config!.services.first,
        app: remoteApp,
        autoStart: false);
    addTearDown(session.dispose);
    final starting = session.start();
    await ssh.requested.future;
    await session.close();
    final tunnel = FakeTunnel();
    ssh.pending.complete(tunnel);
    await starting;
    expect(tunnel.closed, isTrue);
    expect(session.controller, isNull);
    expect(platform.controllers, isEmpty);
  });

  test('closing a previous session keeps the selected session identity',
      () async {
    final a = direct();
    final b = direct();
    final c = direct();
    app.webuiSessions.addAll([a, b, c]);
    app.webuiActiveIndex = 1;
    await app.closeWebuiSession(0);
    expect(app.webuiActiveIndex, 0);
    expect(app.webuiSessions[app.webuiActiveIndex], same(b));
    await app.closeWebuiSession(1);
    await app.closeWebuiSession(0);
    expect(app.webuiActiveIndex, 0);
    expect(app.webuiSessions, isEmpty);
  });
}
