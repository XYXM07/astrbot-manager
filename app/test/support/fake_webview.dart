import 'dart:async';
import 'package:astrbot_manager/models/config.dart';
import 'package:astrbot_manager/services/ssh.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebPlatform extends WebViewPlatform {
  final controllers = <FakeWebController>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    final controller = FakeWebController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
          PlatformNavigationDelegateCreationParams params) =>
      FakeNavigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams params) =>
      FakeWebWidget(params);
}

class FakeWebController extends PlatformWebViewController {
  FakeWebController(super.params) : super.implementation();
  Object? configureError;
  Object? loadError;
  Object? reloadError;
  Completer<void>? configureGate;
  FakeNavigation? delegate;
  final loads = <Uri>[];
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    await configureGate?.future;
    if (configureError != null) throw configureError!;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate delegate) async {
    this.delegate = delegate as FakeNavigation;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    if (loadError != null) throw loadError!;
    loads.add(params.uri);
  }

  @override
  Future<void> reload() async {
    if (reloadError != null) throw reloadError!;
  }
}

class FakeNavigation extends PlatformNavigationDelegate {
  FakeNavigation(super.params) : super.implementation();
  PageEventCallback? started;
  PageEventCallback? finished;
  WebResourceErrorCallback? failed;
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    started = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    failed = callback;
  }
}

class FakeWebWidget extends PlatformWebViewWidget {
  FakeWebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        key: ValueKey('webview-surface'),
        color: Colors.black,
        child: Center(child: Text('WebUI content')),
      );
}

class PendingTunnelSsh extends SshService {
  final requested = Completer<void>();
  final pending = Completer<LocalTunnel>();
  @override
  Future<SSHClient> connect(ServerConfig cfg) async => FakeClient();
  @override
  Future<CmdResult> run(String command,
          {Duration timeout = const Duration(seconds: 30)}) async =>
      const CmdResult(0, 'OPEN', '');
  @override
  Future<LocalTunnel> openTunnel(String remoteHost, int remotePort,
      {int preferredLocalPort = 0}) {
    requested.complete();
    return pending.future;
  }
}

class FakeClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTunnel implements LocalTunnel {
  bool closed = false;
  @override
  int get port => 6185;
  @override
  Future<void> close() async {
    closed = true;
  }
}
