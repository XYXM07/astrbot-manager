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

  WebViewController? controller;
  LocalTunnel? tunnel;
  bool connecting = true;
  String? error;
  String? pageError;

  WebUiSession({required this.id, required this.service, required this.app}) {
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
}
