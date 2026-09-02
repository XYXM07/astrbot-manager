import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/config.dart';
import '../models/settings.dart';
import '../services/frame_rate.dart';
import '../services/manager.dart';
import '../services/ssh.dart';
import '../services/storage.dart';
import '../services/webui_session.dart';

enum ConnState { disconnected, connecting, connected, error }

/// 全局应用状态
class AppState extends ChangeNotifier {
  final StorageService storage;
  final SshService ssh;
  late final ManagerService manager;

  AppState({StorageService? storage, SshService? ssh})
      : storage = storage ?? const StorageService(),
        ssh = ssh ?? SshService() {
    manager = ManagerService(this.ssh);
  }

  bool loading = true;
  ServerConfig? config;
  AppSettings settings = AppSettings();
  ConnState connState = ConnState.disconnected;
  String? connError;
  String? serverInfo;

  /// 服务器资源占用（CPU/内存/磁盘），刷新时更新
  ServerMetrics? metrics;
  final Map<String, ServiceStatus> statuses = {};
  final Set<String> busy = {};
  bool refreshing = false;

  bool get hasConfig => config != null;
  bool get connected => connState == ConnState.connected;

  Future<void> init() async {
    config = await storage.load();
    settings = await storage.loadSettings();
    loading = false;
    notifyListeners();
    // 应用帧率设置（30/60/120/无限制）
    FrameRateService.apply(settings.frameRate);
  }

  /// 更新并持久化 APP 设置
  Future<void> updateSettings(AppSettings s) async {
    final rateChanged = s.frameRate != settings.frameRate;
    settings = s;
    notifyListeners();
    await storage.saveSettings(s);
    if (rateChanged) FrameRateService.apply(s.frameRate);
  }

  /// 测试连接并保存配置；成功返回 true
  Future<bool> connectAndSave(ServerConfig cfg) async {
    connState = ConnState.connecting;
    connError = null;
    serverInfo = null;
    metrics = null;
    statuses.clear();
    notifyListeners();
    try {
      manager.config = cfg;
      serverInfo = await manager.testConnection(cfg);
      config = cfg;
      await storage.save(cfg);
      connState = ConnState.connected;
      notifyListeners();
      return true;
    } catch (e) {
      connState = ConnState.error;
      connError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 连接（如需要）并刷新全部服务状态
  Future<void> refreshAll() async {
    final cfg = config;
    if (cfg == null || refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      manager.config = cfg;
      if (connState != ConnState.connected || !ssh.isConnected) {
        connState = ConnState.connecting;
        notifyListeners();
        await ssh.connect(cfg);
        connState = ConnState.connected;
        connError = null;
      }
      if (serverInfo == null || serverInfo!.isEmpty) {
        try {
          final r = await ssh.run('uname -srm');
          if (r.ok) serverInfo = r.stdout.trim();
        } catch (_) {}
      }
      await Future.wait(cfg.services.map(refreshOne));
      // 资源监控（失败不影响整体刷新，保留上次数据）
      try {
        final m = await manager.metricsOf();
        metrics = m;
      } catch (_) {}
    } catch (e) {
      connError = e.toString();
      connState = ConnState.error;
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshOne(ServiceConfig s) async {
    try {
      final st = await manager.statusOf(s);
      statuses[s.id] = st;
    } catch (e) {
      statuses[s.id] = ServiceStatus.error(e.toString());
    }
    notifyListeners();
  }

  ServiceStatus statusOf(ServiceConfig s) =>
      statuses[s.id] ?? ServiceStatus.unknown();

  /// 远程重启；成功返回 true
  Future<bool> restart(ServiceConfig s) async {
    if (busy.contains(s.id)) return false;
    busy.add(s.id);
    statuses[s.id] = ServiceStatus.restarting();
    notifyListeners();
    try {
      await manager.restart(s);
      await Future<void>.delayed(const Duration(seconds: 3));
      await refreshOne(s);
      return true;
    } catch (e) {
      statuses[s.id] = ServiceStatus.error(e.toString());
      return false;
    } finally {
      busy.remove(s.id);
      notifyListeners();
    }
  }

  Future<String> fetchLogs(ServiceConfig s, {int lines = 200}) =>
      manager.logsOf(s, lines: lines);

  Future<List<ContainerInfo>> detectContainers() => manager.listContainers();

  Future<void> saveService(ServiceConfig s) async {
    final cfg = config;
    if (cfg == null) return;
    final idx = cfg.services.indexWhere((x) => x.id == s.id);
    if (idx >= 0) {
      cfg.services[idx] = s;
    } else {
      cfg.services.add(s);
    }
    statuses.remove(s.id);
    await storage.save(cfg);
    notifyListeners();
  }

  Future<void> removeService(String id) async {
    final cfg = config;
    if (cfg == null) return;
    cfg.services.removeWhere((x) => x.id == id);
    statuses.remove(id);
    await storage.save(cfg);
    notifyListeners();
  }

  /// WebUI 会话列表（多开，切页常驻）
  final List<WebUiSession> webuiSessions = [];
  int webuiActiveIndex = 0;

  /// 打开一个新 WebUI 会话并激活
  WebUiSession openWebuiSession(ServiceConfig s) {
    final sess = WebUiSession(
      id: 'web_${DateTime.now().millisecondsSinceEpoch}',
      service: s,
      app: this,
    );
    webuiSessions.add(sess);
    webuiActiveIndex = webuiSessions.length - 1;
    notifyListeners();
    return sess;
  }

  /// 打开自定义网址会话（直连，无需 SSH 隧道）；已存在相同网址则复用
  void openCustomWebui(String url) {
    final cfg = config;
    if (cfg == null) return;
    final u = url.trim();
    if (u.isEmpty) return;
    final existing = webuiSessions.indexWhere((s) => s.directUrl == u);
    if (existing >= 0) {
      webuiActiveIndex = existing;
      notifyListeners();
      return;
    }
    final svc = cfg.services.firstWhere(
      (s) => s.id == 'astrbot',
      orElse: () => cfg.services.first,
    );
    final sess = WebUiSession(
      id: 'web_${DateTime.now().millisecondsSinceEpoch}',
      service: svc,
      app: this,
      directUrl: u,
    );
    webuiSessions.add(sess);
    webuiActiveIndex = webuiSessions.length - 1;
    notifyListeners();
  }

  void selectWebuiSession(int index) {
    if (index < 0 || index >= webuiSessions.length) return;
    webuiActiveIndex = index;
    notifyListeners();
  }

  Future<void> closeWebuiSession(int index) async {
    if (index < 0 || index >= webuiSessions.length) return;
    final s = webuiSessions.removeAt(index);
    await s.close();
    if (webuiActiveIndex >= webuiSessions.length) {
      webuiActiveIndex = webuiSessions.length - 1;
    }
    notifyListeners();
  }

  void disconnect() {
    ssh.disconnect();
    connState = ConnState.disconnected;
    metrics = null;
    notifyListeners();
  }

  /// App 回到前台：检测 SSH 假死并自动重连，恢复 WebUI 会话。
  /// Android 切后台后系统会冻结进程/休眠网络，SSH 长连接经常假死，
  /// 这里统一做"探测 → 断线重建 → 隧道会话重启 → 页面重载"。
  Future<void> onAppResumed() async {
    final cfg = config;
    if (cfg == null || loading || refreshing) return;
    if (!ssh.isConnected) {
      // 连接已断：整体重连 + 重建 WebUI 隧道会话
      await refreshAll();
      for (final s in webuiSessions) {
        unawaited(s.start());
      }
      return;
    }
    final alive = await ssh.ping();
    if (!alive) {
      // 假死连接：丢弃旧客户端后重连
      ssh.disconnect();
      connState = ConnState.disconnected;
      metrics = null;
      notifyListeners();
      await refreshAll();
      for (final s in webuiSessions) {
        unawaited(s.start());
      }
    } else {
      // 连接正常：WebView 页面可能已被系统销毁，重载当前页
      for (final s in webuiSessions) {
        final c = s.controller;
        if (c != null && s.error == null) {
          unawaited(c.reload());
        }
      }
    }
  }
}
