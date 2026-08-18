import 'dart:async';

import '../l10n.dart';
import '../models/config.dart';
import 'ssh.dart';

/// 容器列表项（服务器自动检测）
class ContainerInfo {
  final String name;
  final String state;
  final String status;
  const ContainerInfo(this.name, this.state, this.status);
}

/// 服务运行状态
class ServiceStatus {
  final String state;
  final DateTime? startedAt;
  final int? exitCode;
  final String? image;
  final String? message;

  const ServiceStatus({
    required this.state,
    this.startedAt,
    this.exitCode,
    this.image,
    this.message,
  });

  bool get running => state == 'running';
  bool get isError => state == 'error';

  factory ServiceStatus.missing() => const ServiceStatus(state: 'missing');
  factory ServiceStatus.restarting() => const ServiceStatus(state: 'restarting');
  factory ServiceStatus.unknown() => const ServiceStatus(state: 'unknown');
  factory ServiceStatus.error(String msg) =>
      ServiceStatus(state: 'error', message: msg);
}

/// 服务器端管理操作：状态查询 / 远程重启 / 日志拉取
class ManagerService {
  final SshService ssh;
  ServerConfig? config;

  ManagerService(this.ssh);

  String _cmd(String c) {
    final cfg = config;
    return (cfg != null && cfg.useSudo) ? 'sudo $c' : c;
  }

  /// 测试连接并探测服务器信息
  Future<String> testConnection(ServerConfig cfg) async {
    config = cfg;
    await ssh.connect(cfg);
    final r = await ssh.run(_cmd('echo ASTROBOT_OK && uname -srm'));
    if (!r.ok || !r.stdout.contains('ASTROBOT_OK')) {
      throw SshException(
        r.stderr.trim().isEmpty ? L10n.t('基础命令执行失败') : r.stderr.trim(),
      );
    }
    final uname = r.stdout.replaceAll('ASTROBOT_OK', '').trim();
    var docker = L10n.t('Docker：未检测到');
    try {
      final d = await ssh.run(_cmd('docker --version'));
      if (d.ok && d.stdout.trim().isNotEmpty) docker = d.stdout.trim();
    } catch (_) {}
    return '$uname\n$docker';
  }

  /// 列出服务器上的所有容器（用于自动检测容器名）
  Future<List<ContainerInfo>> listContainers() async {
    final r = await ssh.run(
      _cmd(r"docker ps -a --format '{{.Names}}\t{{.State}}\t{{.Status}}'"),
      timeout: const Duration(seconds: 20),
    );
    if (!r.ok) {
      throw SshException(
        r.stderr.trim().isEmpty ? L10n.t('无法获取容器列表（Docker 不可用？）') : r.stderr.trim(),
      );
    }
    final result = <ContainerInfo>[];
    for (final line in r.stdout.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      result.add(ContainerInfo(
        parts[0].trim(),
        parts.length > 1 ? parts[1].trim() : '',
        parts.length > 2 ? parts[2].trim() : '',
      ));
    }
    return result;
  }

  Future<ServiceStatus> statusOf(ServiceConfig s) async {
    switch (s.kind) {
      case ServiceKind.container:
        return _containerStatus(s.target);
      case ServiceKind.compose:
        return _composeStatus(s);
      case ServiceKind.systemd:
        return _systemdStatus(s.target);
    }
  }

  Future<ServiceStatus> _containerStatus(String name) async {
    final r = await ssh.run(
      _cmd(
        "docker inspect -f '{{.State.Status}}|{{.State.StartedAt}}|{{.State.ExitCode}}|{{.Config.Image}}' '$name'",
      ),
    );
    if (r.exitCode != 0) {
      final t = (r.stderr + r.stdout).toLowerCase();
      if (t.contains('no such object') || t.contains('no such container')) {
        return ServiceStatus.missing();
      }
      throw SshException(
        r.stderr.trim().isEmpty ? L10n.t('无法获取容器状态') : r.stderr.trim(),
      );
    }
    final parts = r.stdout.trim().split('|');
    if (parts.isEmpty) return ServiceStatus.unknown();
    final state = parts[0].trim();
    final started = parts.length > 1 ? DateTime.tryParse(parts[1].trim()) : null;
    final exitCode = parts.length > 2 ? int.tryParse(parts[2].trim()) : null;
    final image = parts.length > 3 ? parts[3].trim() : null;
    return ServiceStatus(
      state: state,
      startedAt: started,
      exitCode: exitCode,
      image: image,
    );
  }

  Future<ServiceStatus> _composeStatus(ServiceConfig s) async {
    final file = s.composeFile.trim().isEmpty ? '' : "-f '${s.composeFile}' ";
    final r = await ssh.run(_cmd("docker compose $file ps -a -q '${s.target}'"));
    if (!r.ok) {
      throw SshException(
        r.stderr.trim().isEmpty ? L10n.t('无法查询 Compose 服务') : r.stderr.trim(),
      );
    }
    final id = r.stdout.trim().split('\n').first.trim();
    if (id.isEmpty) return ServiceStatus.missing();
    return _containerStatus(id);
  }

  Future<ServiceStatus> _systemdStatus(String name) async {
    final r = await ssh.run(
      _cmd(
        "systemctl is-active '$name'; systemctl show -p ActiveEnterTimestamp --value '$name'",
      ),
      timeout: const Duration(seconds: 15),
    );
    final lines = r.stdout.trim().split('\n');
    final active = lines.isNotEmpty ? lines[0].trim() : 'unknown';
    final rawTs = lines.length > 1 ? lines[1].trim() : '';
    DateTime? started;
    if (rawTs.isNotEmpty) {
      final m =
          RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}').firstMatch(rawTs);
      if (m != null) started = DateTime.tryParse(m.group(0)!);
    }
    return ServiceStatus(state: active, startedAt: started);
  }

  /// 远程重启服务
  Future<void> restart(ServiceConfig s) async {
    final CmdResult r;
    if (s.kind == ServiceKind.container) {
      r = await ssh.run(_cmd("docker restart -t 15 '${s.target}'"));
    } else if (s.kind == ServiceKind.compose) {
      final file = s.composeFile.trim().isEmpty ? '' : "-f '${s.composeFile}' ";
      r = await ssh.run(
        _cmd("docker compose $file restart -t 15 '${s.target}'"),
        timeout: const Duration(seconds: 60),
      );
    } else {
      r = await ssh.run(
        _cmd("systemctl restart '${s.target}'"),
        timeout: const Duration(seconds: 60),
      );
    }
    if (!r.ok) {
      throw SshException(
        r.stderr.trim().isEmpty ? L10n.t('重启失败（退出码 {code}）', {'code': '${r.exitCode}'}) : r.stderr.trim(),
      );
    }
  }

  /// 检测服务器上某端口是否在监听（用于 WebUI 预检）
  Future<bool> portListening(int port) async {
    final r = await ssh.run(
      _cmd(
        "bash -c '(echo > /dev/tcp/127.0.0.1/$port) 2>/dev/null && echo OPEN || echo CLOSED'",
      ),
      timeout: const Duration(seconds: 10),
    );
    return r.stdout.contains('OPEN');
  }

  /// 拉取最近日志
  Future<String> logsOf(ServiceConfig s, {int lines = 200}) async {
    final CmdResult r;
    if (s.kind == ServiceKind.container) {
      r = await ssh.run(
        _cmd("docker logs --tail $lines -t '${s.target}' 2>&1"),
        timeout: const Duration(seconds: 20),
      );
    } else if (s.kind == ServiceKind.compose) {
      final file = s.composeFile.trim().isEmpty ? '' : "-f '${s.composeFile}' ";
      r = await ssh.run(
        _cmd(
          "docker compose $file logs --tail $lines -t --no-color '${s.target}' 2>&1",
        ),
        timeout: const Duration(seconds: 20),
      );
    } else {
      r = await ssh.run(
        _cmd("journalctl -u '${s.target}' -n $lines --no-pager -o short-iso 2>&1"),
        timeout: const Duration(seconds: 20),
      );
    }
    if (!r.ok) {
      throw SshException(
        r.stderr.trim().isEmpty ? L10n.t('无法获取日志') : r.stderr.trim(),
      );
    }
    return r.stdout.trim();
  }
}
