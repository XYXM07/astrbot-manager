import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n.dart';
import '../models/config.dart';
import '../state/app_state.dart';
import 'ssh.dart';

/// Owns one WebView and tunnel. Closing invalidates pending callbacks.
class WebUiSession extends ChangeNotifier {
  final String id;
  final ServiceConfig service;
  final AppState app;
  final String? directUrl;
  final WebViewController Function() _createController;

  WebViewController? controller;
  LocalTunnel? tunnel;
  bool connecting = true;
  String? error;
  String? pageError;
  bool _closed = false;
  int _generation = 0;
  Future<void>? _starting;
  Timer? _pageTimeout;

  String get label {
    if (directUrl == null) return service.name;
    final host = Uri.tryParse(directUrl!)?.host ?? '';
    return host.isEmpty ? L10n.t('自定义网址') : host;
  }

  WebUiSession({
    required this.id,
    required this.service,
    required this.app,
    this.directUrl,
    WebViewController Function()? controllerFactory,
    bool autoStart = true,
  }) : _createController = controllerFactory ?? WebViewController.new {
    if (autoStart) unawaited(start());
  }

  bool _current(int generation) => !_closed && generation == _generation;

  void _notify() {
    if (!_closed) notifyListeners();
  }

  /// Coalesce retries instead of creating competing native views.
  Future<void> start() {
    if (_closed) return Future.value();
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final generation = ++_generation;
    _pageTimeout?.cancel();
    connecting = true;
    error = null;
    pageError = null;
    _notify();
    LocalTunnel? opened;
    try {
      final oldTunnel = tunnel;
      tunnel = null;
      await oldTunnel?.close();
      if (!_current(generation)) return;
      Uri url;
      if (directUrl != null) {
        url = Uri.parse(directUrl!);
        if (!{'http', 'https'}.contains(url.scheme) || url.host.isEmpty) {
          throw FormatException(L10n.t('请输入要打开的网址（以 http:// 或 https:// 开头）'));
        }
      } else {
        final cfg = app.config;
        if (cfg == null) throw SshException(L10n.t('缺少服务器配置'));
        await app.ssh.connect(cfg);
        if (!_current(generation)) return;
        final listening = await app.manager.portListening(service.webuiPort);
        if (!_current(generation)) return;
        if (!listening) {
          throw SshException(L10n.t(
            '服务器 127.0.0.1:{port} 端口未监听\n请确认 {name} 的 WebUI 已开启，或端口配置有误',
            {'port': '${service.webuiPort}', 'name': service.name},
          ));
        }
        opened = await app.ssh.openTunnel('127.0.0.1', service.webuiPort,
            preferredLocalPort: service.webuiPort);
        if (!_current(generation)) {
          await opened.close();
          return;
        }
        final raw = service.webuiPath.trim();
        var path = raw.isEmpty ? '/' : (raw.startsWith('/') ? raw : '/$raw');
        if (service.webuiToken.trim().isNotEmpty && !path.contains('token=')) {
          path +=
              '${path.contains('?') ? '&' : '?'}token=${Uri.encodeQueryComponent(service.webuiToken.trim())}';
        }
        url = Uri.parse('http://127.0.0.1:${opened.port}$path');
      }

      // Await platform calls: cascaded Futures previously escaped try/catch.
      final c = controller ?? _createController();
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!_current(generation)) return;
      await c.setBackgroundColor(const Color(0xFF0B0E1E));
      if (!_current(generation)) return;
      await c.setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (!_current(generation)) return;
          connecting = true;
          pageError = null;
          _watchPage(generation);
          _notify();
        },
        onPageFinished: (_) {
          if (!_current(generation)) return;
          _pageTimeout?.cancel();
          connecting = false;
          _notify();
        },
        onWebResourceError: (e) {
          if (!_current(generation) || e.isForMainFrame == false) return;
          _pageTimeout?.cancel();
          connecting = false;
          pageError = e.description;
          _notify();
        },
      ));
      if (!_current(generation)) return;
      tunnel = opened;
      controller = c;
      _watchPage(generation);
      _notify();
      await c.loadRequest(url);
    } catch (e) {
      if (_current(generation)) {
        _pageTimeout?.cancel();
        connecting = false;
        error = e.toString();
        tunnel = null;
        _notify();
      }
    } finally {
      if (opened != null && (!_current(generation) || error != null)) {
        await opened.close();
      }
    }
  }

  void _watchPage(int generation) {
    _pageTimeout?.cancel();
    _pageTimeout = Timer(const Duration(seconds: 30), () {
      if (!_current(generation)) return;
      connecting = false;
      pageError = L10n.t('页面加载超时，请重试或关闭会话');
      _notify();
    });
  }

  /// Preserve the actual local port, including a random-port fallback.
  Future<void> restartTunnel() async {
    if (_closed || directUrl != null) return;
    if (_starting != null) return _starting;
    final cfg = app.config;
    final old = tunnel;
    if (cfg == null) return;
    if (old == null) return start();
    final generation = _generation;
    final port = old.port;
    tunnel = null;
    await old.close();
    try {
      await app.ssh.connect(cfg);
      if (!_current(generation)) return;
      final replacement = await app.ssh
          .openTunnel('127.0.0.1', service.webuiPort, preferredLocalPort: port);
      if (!_current(generation) || tunnel != null) {
        await replacement.close();
        return;
      }
      tunnel = replacement;
      error = null;
      if (replacement.port != port) {
        await start();
      } else {
        _notify();
      }
    } catch (e) {
      if (!_current(generation)) return;
      error = e.toString();
      _notify();
    }
  }

  Future<void> reloadPage() async {
    if (_closed) return;
    final c = controller;
    if (c == null || error != null) return start();
    final generation = _generation;
    pageError = null;
    connecting = true;
    _watchPage(generation);
    _notify();
    try {
      await c.reload();
    } catch (e) {
      if (!_current(generation)) return;
      _pageTimeout?.cancel();
      connecting = false;
      pageError = e.toString();
      _notify();
    }
  }

  Future<void> close() async {
    _closed = true;
    _generation++;
    _pageTimeout?.cancel();
    controller = null;
    final old = tunnel;
    tunnel = null;
    await old?.close();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
