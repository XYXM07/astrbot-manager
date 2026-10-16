import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// dartssh2 may close from a stream's onDone without awaiting the result.
/// Transport errors still reach its stream/done; closing must not emit a second
/// unhandled SocketException when a peer resets while data is being written.
class _ClosingSshSocket implements SSHSocket {
  final SSHSocket _socket;
  Future<void>? _closing;
  _ClosingSshSocket(this._socket);
  @override
  Stream<Uint8List> get stream => _socket.stream;
  @override
  StreamSink<List<int>> get sink => _socket.sink;
  @override
  Future<void> get done => _socket.done;
  @override
  Future<void> flush() => _socket.flush();
  @override
  void destroy() => _socket.destroy();
  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    try {
      await _socket.close();
    } catch (_) {
      _socket.destroy();
    }
  }
}

/// 本地 TCP 端口转发隧道：把手机上的本地端口经 SSH 转发到服务器端口
/// （用于在 APP 内安全访问 AstrBot / NapCat 的 WebUI，无需在公网开放端口）
class LocalTunnel {
  final ServerSocket _server;
  final SSHClient _client;
  final List<SSHForwardChannel> _channels = [];
  final Set<Socket> _sockets = {};
  bool _closed = false;

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
      unawaited(_handleConnection(tunnel, socket, remoteHost, remotePort));
    }, onError: (Object _) {
      unawaited(tunnel.close());
    });
    return tunnel;
  }

  static Future<void> _handleConnection(
    LocalTunnel tunnel,
    Socket socket,
    String remoteHost,
    int remotePort,
  ) async {
    if (tunnel._closed) {
      socket.destroy();
      return;
    }
    tunnel._sockets.add(socket);
    SSHForwardChannel? channel;
    bool channelDestroyed = false;
    void cleanup() {
      socket.destroy();
      tunnel._sockets.remove(socket);
      final current = channel;
      if (current != null && !channelDestroyed) {
        channelDestroyed = true;
        current.destroy();
        tunnel._channels.remove(current);
      }
    }

    // Consume socket errors immediately, including before SSH opens a channel.
    unawaited(socket.done.then<void>((_) => cleanup(),
        onError: (Object _, StackTrace __) => cleanup()));
    try {
      final fwd =
          await tunnel._client.forwardLocal(remoteHost, remotePort).then((fwd) {
        if (tunnel._closed || !tunnel._sockets.contains(socket)) fwd.destroy();
        return fwd;
      }).timeout(const Duration(seconds: 12));
      channel = fwd;
      if (tunnel._closed || !tunnel._sockets.contains(socket)) {
        cleanup();
        return;
      }
      tunnel._channels.add(fwd);
      // pipe propagates backpressure; both completion paths consume errors.
      unawaited(fwd.stream.cast<List<int>>().pipe(socket).then<void>(
          (_) => cleanup(),
          onError: (Object _, StackTrace __) => cleanup()));
      unawaited(socket.cast<List<int>>().pipe(fwd.sink).then<void>(
          (_) => cleanup(),
          onError: (Object _, StackTrace __) => cleanup()));
    } catch (_) {
      cleanup();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    _sockets.clear();
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
  Future<SSHClient>? _connecting;
  int _connectionGeneration = 0;

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
    _connectionGeneration++;
    _connecting = null;
    final client = _client;
    if (client != null) {
      unawaited(client
          .close()
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    }
    _client = null;
    _cfg = null;
  }

  /// 建立连接（若配置未变且连接仍有效则复用）
  Future<SSHClient> connect(ServerConfig cfg) {
    if (_cfg == cfg && _client != null && !_client!.isClosed) {
      return Future.value(_client!);
    }
    if (_cfg == cfg && _connecting != null) return _connecting!;
    disconnect();
    _cfg = cfg;
    final generation = _connectionGeneration;
    return _connecting = _connect(cfg, generation);
  }

  Future<SSHClient> _connect(ServerConfig cfg, int generation) async {
    SSHClient? candidate;
    SSHSocket? transport;
    try {
      final socket = _ClosingSshSocket(await SSHSocket.connect(
        cfg.host,
        cfg.port,
        timeout: const Duration(seconds: 12),
      ));
      transport = socket;
      unawaited(socket.done
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
      if (generation != _connectionGeneration) {
        socket.destroy();
        throw SshException(L10n.t('SSH 会话已断开，请重新连接'));
      }
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
      candidate = client;
      unawaited(client.done
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
      await client.authenticated.timeout(const Duration(seconds: 20));
      if (generation != _connectionGeneration) {
        throw SshException(L10n.t('SSH 会话已断开，请重新连接'));
      }
      _client = client;
      return client;
    } catch (e) {
      if (candidate != null) {
        try {
          await candidate.close();
        } catch (_) {}
      } else {
        transport?.destroy();
      }
      if (generation == _connectionGeneration) disconnect();
      throw SshException(_friendly(e));
    } finally {
      if (generation == _connectionGeneration) _connecting = null;
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

  /// 探测当前 SSH 连接是否仍可用（用于切后台回来后的假死检测）
  Future<bool> ping() async {
    final client = _client;
    if (client == null || client.isClosed) return false;
    try {
      final r = await run('echo pong', timeout: const Duration(seconds: 6));
      return r.ok;
    } catch (_) {
      return false;
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
