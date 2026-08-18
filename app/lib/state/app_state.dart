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

  /// 打开一个新的 WebUI 会话并激活
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
    notifyListeners();
  }
}
