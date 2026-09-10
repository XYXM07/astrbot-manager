import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n.dart';
import '../models/config.dart';
import '../state/app_state.dart';
import 'ssh.dart';

/// 一个可常驻的 WebUI 会话：持有独立隧道 + WebView，可在多个页面间保持存活，
/// 支持多开（同一服务可开多个会话）。
class WebUiSession extends ChangeNotifier {
  final String id;
  final ServiceConfig service;
  final AppState app;

  /// 直连模式：直接加载外部地址（自定义网址），无需 SSH 隧道
  final String? directUrl;

  WebViewController? controller;
  LocalTunnel? tunnel;
  bool connecting = true;
  String? error;
  String? pageError;

  /// 会话标签：直连模式显示网址主机名，隧道模式显示服务名
  String get label {
    final d = directUrl;
    if (d == null) return service.name;
    try {
      final h = Uri.parse(d).host;
      return h.isEmpty ? L10n.t('自定义网址') : h;
    } catch (_) {
      return L10n.t('自定义网址');
    }
  }

  WebUiSession({
    required this.id,
    required this.service,
    required this.app,
    this.directUrl,
  }) {
    start();
  }

  Future<void> start() async {
    final cfg = app.config;
    if (cfg == null) {
      error = L10n.t('缺少服务器配置');
      connecting = false;
      notifyListeners();
      return;
    }
    connecting = true;
    error = null;
    pageError = null;
    notifyListeners();

    // 直连模式：无 SSH，直接加载外部网址
    if (directUrl != null) {
      try {
        final c = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF0B0E1E))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (pageError != null) {
                  pageError = null;
                  notifyListeners();
                }
              },
              onPageFinished: (_) {
                connecting = false;
                notifyListeners();
              },
              onWebResourceError: (e) {
                if (e.isForMainFrame == true) {
                  pageError = e.description ?? L10n.t('页面加载失败');
                  notifyListeners();
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(directUrl!));
        tunnel = null;
        controller = c;
      } catch (e) {
        error = L10n.t('无法打开网址：{err}', {'err': '$e'});
      }
      connecting = false;
      notifyListeners();
      return;
    }

    await tunnel?.close();
    try {
      await app.ssh.connect(cfg);
      // 预检：服务器上 WebUI 端口是否在监听
      final open = await app.manager.portListening(service.webuiPort);
      if (!open) {
        throw SshException(
          L10n.t(
            '服务器 127.0.0.1:{port} 端口未监听\n请确认 {name} 的 WebUI 已开启，或端口配置有误',
            {'port': '${service.webuiPort}', 'name': service.name},
          ),
        );
      }
      // 固定本机端口 = WebUI 端口，保证 localStorage 源稳定（登录状态可持久）
      final t = await app.ssh.openTunnel(
        '127.0.0.1',
        service.webuiPort,
        preferredLocalPort: service.webuiPort,
      );
      final rawPath = service.webuiPath.trim();
      final urlPath = rawPath.isEmpty
          ? '/'
          : (rawPath.startsWith('/') ? rawPath : '/$rawPath');
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0B0E1E))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (pageError != null) {
                pageError = null;
                notifyListeners();
              }
            },
            onPageFinished: (_) {
              connecting = false;
              notifyListeners();
            },
            onWebResourceError: (e) {
              if (e.isForMainFrame == true) {
                pageError = e.description ?? L10n.t('页面加载失败');
                notifyListeners();
              }
            },
          ),
        )
        ..loadRequest(Uri.parse('http://127.0.0.1:${t.port}$urlPath'));
      tunnel = t;
      controller = c;
    } catch (e) {
      error = e.toString();
    }
    connecting = false;
    notifyListeners();
  }

  /// 关闭隧道（WebView 数据由系统 WebView 存储，登录态不受影响）
  Future<void> close() async {
    await tunnel?.close();
    tunnel = null;
  }

  /// 仅重建 SSH 隧道，保留当前 WebView 页面。
  /// 本机端口固定为 WebUI 端口，页面里的 WebSocket 会自动接到新隧道，
  /// 因此无需重载页面（重载会丢失 NapCat 等后台的登录态）。
  Future<void> restartTunnel() async {
    if (directUrl != null) return; // 直连模式没有隧道
    final cfg = app.config;
    if (cfg == null) return;
    if (tunnel == null) {
      // 本来就没有隧道（例如上次连接失败）：整体重建
      await start();
      return;
    }
    try {
      await tunnel?.close();
      tunnel = null;
      await app.ssh.connect(cfg);
      final t = await app.ssh.openTunnel(
        '127.0.0.1',
        service.webuiPort,
        preferredLocalPort: service.webuiPort,
      );
      tunnel = t;
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  /// 重新加载当前页面（页面本身加载失败时使用）
  Future<void> reloadPage() async {
    final c = controller;
    if (c == null) {
      await start();
      return;
    }
    pageError = null;
    notifyListeners();
    await c.reload();
  }
}
