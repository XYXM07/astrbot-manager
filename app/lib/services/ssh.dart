import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../l10n.dart';
import '../models/config.dart';

/// 带友好提示的 SSH 异常
class SshException implements Exception {
  final String message;
  const SshException(this.message);

  @override
  String toString() => message;
}

/// 命令执行结果
class CmdResult {
  final int? exitCode;
  final String stdout;
  final String stderr;
  const CmdResult(this.exitCode, this.stdout, this.stderr);

  bool get ok => exitCode == 0;
}

/// 本地 TCP 端口转发隧道：把手机上的本地端口经 SSH 转发到服务器端口
/// （用于在 APP 内安全访问 AstrBot / NapCat 的 WebUI，无需在公网开放端口）
class LocalTunnel {
  final ServerSocket _server;
  final SSHClient _client;
  final List<SSHForwardChannel> _channels = [];

  LocalTunnel._(this._server, this._client);

  /// 本机监听端口
  int get port => _server.port;

  /// [preferredLocalPort] 用于固定本机端口（保证网页 localStorage 源一致，
  /// 登录状态才能持久化）；被占用时自动回退为随机端口。
  static Future<LocalTunnel> open(
    SSHClient client,
    String remoteHost,
    int remotePort, {
    int preferredLocalPort = 0,
  }) async {
    ServerSocket? server;
    if (preferredLocalPort > 0) {
      try {
        server = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          preferredLocalPort,
        );
      } catch (_) {
        server = null;
      }
    }
    server ??= await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final tunnel = LocalTunnel._(server, client);
    server.listen((socket) {
      _handleConnection(tunnel, socket, remoteHost, remotePort);
    });
    return tunnel;
  }

  static Future<void> _handleConnection(
    LocalTunnel tunnel,
    Socket socket,
    String remoteHost,
    int remotePort,
  ) async {
    try {
      final fwd = await tunnel._client.forwardLocal(remoteHost, remotePort);
      tunnel._channels.add(fwd);
      // 服务器 -> 浏览器
      fwd.stream.listen(
        (data) {
          try {
            socket.add(data);
          } catch (_) {}
        },
        onDone: () {
          try {
            socket.destroy();
          } catch (_) {}
        },
        onError: (_) {
          try {
            socket.destroy();
          } catch (_) {}
        },
      );
      // 浏览器 -> 服务器
      socket.listen(
        (data) {
          try {
            fwd.sink.add(data);
          } catch (_) {}
        },
        onDone: () {
          try {
            fwd.close();
          } catch (_) {}
        },
        onError: (_) {
          try {
            fwd.close();
          } catch (_) {}
        },
      );
      socket.done.whenComplete(() {
        try {
          fwd.destroy();
        } catch (_) {}
        tunnel._channels.remove(fwd);
      });
    } catch (_) {
      try {
        socket.destroy();
      } catch (_) {}
    }
  }

  Future<void> close() async {
    for (final c in List.of(_channels)) {
      try {
        c.destroy();
      } catch (_) {}
    }
    _channels.clear();
    try {
      await _server.close();
    } catch (_) {}
  }
}

/// SSH 连接与命令执行服务（基于 dartssh2）
class SshService {
  ServerConfig? _cfg;
  SSHClient? _client;

  bool get isConnected => _client != null && !_client!.isClosed;

  /// 当前活跃的 SSH 客户端（供隧道等高级功能使用）
  SSHClient? get client => _client;

  /// 建立到服务器某端口的本地隧道
  Future<LocalTunnel> openTunnel(
    String remoteHost,
    int remotePort, {
    int preferredLocalPort = 0,
  }) async {
    final c = _client;
    if (c == null || c.isClosed) {
      throw SshException(L10n.t('尚未连接服务器'));
    }
    return LocalTunnel.open(
      c,
      remoteHost,
      remotePort,
      preferredLocalPort: preferredLocalPort,
    );
  }

  void disconnect() {
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
    _cfg = null;
  }

  /// 建立连接（若配置未变且连接仍有效则复用）
  Future<SSHClient> connect(ServerConfig cfg) async {
    if (_cfg == cfg && _client != null && !_client!.isClosed) {
      return _client!;
    }
    disconnect();
    _cfg = cfg;
    try {
      final socket = await SSHSocket.connect(
        cfg.host,
        cfg.port,
        timeout: const Duration(seconds: 12),
      );
      final client = SSHClient(
        socket,
        username: cfg.username,
        onPasswordRequest: cfg.useKey ? null : () => cfg.password,
        identities: cfg.useKey
            ? SSHKeyPair.fromPem(
                cfg.privateKey,
                cfg.keyPassphrase.isEmpty ? null : cfg.keyPassphrase,
              )
            : null,
        keepAliveInterval: const Duration(seconds: 15),
        handshakeTimeout: const Duration(seconds: 15),
        authTimeout: const Duration(seconds: 15),
      );
      await client.authenticated.timeout(const Duration(seconds: 20));
      _client = client;
      return client;
    } catch (e) {
      disconnect();
      throw SshException(_friendly(e));
    }
  }

  /// 执行远程命令，返回退出码与输出；传输层错误抛出 [SshException]
  Future<CmdResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final client = _client;
    if (client == null || client.isClosed) {
      throw SshException(L10n.t('尚未连接服务器'));
    }
    try {
      final session = await client.execute(command);
      final out = <int>[];
      final err = <int>[];
      final sub1 = session.stdout.listen(out.addAll);
      final sub2 = session.stderr.listen(err.addAll);
      int? exitCode;
      try {
        exitCode = await session.waitForExit(timeout: timeout);
      } finally {
        await sub1.cancel();
        await sub2.cancel();
      }
      return CmdResult(
        exitCode,
        utf8.decode(out, allowMalformed: true),
        utf8.decode(err, allowMalformed: true),
      );
    } on TimeoutException {
      throw SshException(L10n.t('命令执行超时'));
    } on SshException {
      rethrow;
    } catch (e) {
      throw SshException(_friendly(e));
    }
  }

  String _friendly(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('refused')) {
      return L10n.t('连接被拒绝：请检查 IP/端口，以及阿里云安全组是否放行 SSH 端口');
    }
    if (t.contains('timed out') || t.contains('timeout')) {
      return L10n.t('连接超时：请检查网络与服务器地址');
    }
    if (t.contains('getaddrinfo') ||
        t.contains('resolve') ||
        t.contains('unknown host') ||
        t.contains('nodename')) {
      return L10n.t('无法解析主机名，请检查服务器地址');
    }
    if (t.contains('permission denied') ||
        t.contains('no more authentication') ||
        t.contains('auth')) {
      return L10n.t('SSH 认证失败：请检查用户名、密码或私钥');
    }
    if (t.contains('bad state') || t.contains('closed')) {
      return L10n.t('SSH 会话已断开，请重新连接');
    }
    final s = e.toString();
    return s.length > 160 ? s.substring(0, 160) : s;
  }
}
