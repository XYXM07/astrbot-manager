import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:astrbot_manager/models/config.dart';
import 'package:astrbot_manager/services/ssh.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent SSH connection requests share one handshake', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    var accepted = 0;
    server.listen((socket) {
      accepted++;
      socket.destroy();
    });
    final ssh = SshService();
    addTearDown(ssh.disconnect);
    final cfg = ServerConfig.defaults()
      ..host = '127.0.0.1'
      ..port = server.port;
    final first = ssh.connect(cfg);
    final second = ssh.connect(cfg);
    expect(second, same(first));
    await expectLater(first, throwsA(isA<SshException>()));
    expect(accepted, 1);
  });

  test(
      'closing a tunnel while a forwarded connection opens destroys late channels',
      () async {
    final client = ForwardClient();
    final tunnel = await LocalTunnel.open(client, '127.0.0.1', 6185);
    final browser = await Socket.connect('127.0.0.1', tunnel.port);
    browser.listen((_) {}, onError: (Object _) {});
    unawaited(
        browser.done.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    addTearDown(browser.destroy);
    await client.requested.future;
    await tunnel.close();
    final channel = EchoChannel();
    client.pending.complete(channel);
    await channel.destroyed.future;
    expect(channel.isDestroyed, isTrue);
    await tunnel.close();
  });

  test('tunnel forwards browser traffic and consumes a remote stream failure',
      () async {
    final client = ForwardClient();
    final channel = EchoChannel();
    client.pending.complete(channel);
    final tunnel = await LocalTunnel.open(client, '127.0.0.1', 6185);
    addTearDown(tunnel.close);
    final browser = await Socket.connect('127.0.0.1', tunnel.port);
    addTearDown(browser.destroy);
    unawaited(
        browser.done.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    final received = Completer<String>();
    browser.cast<List<int>>().transform(utf8.decoder).listen((text) {
      if (!received.isCompleted) received.complete(text);
    }, onError: (Object _) {});
    browser.add(utf8.encode('websocket-payload'));
    await browser.flush();
    expect(await received.future, 'websocket-payload');
    channel.incoming.addError(StateError('remote disconnected'));
    await channel.destroyed.future;
    expect(channel.isDestroyed, isTrue);
  });
}

class ForwardClient implements SSHClient {
  final requested = Completer<void>();
  final pending = Completer<SSHForwardChannel>();
  @override
  Future<SSHForwardChannel> forwardLocal(String host, int port,
      {String localHost = 'localhost', int localPort = 0}) {
    requested.complete();
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EchoChannel implements SSHForwardChannel {
  final incoming = StreamController<Uint8List>();
  final outgoing = StreamController<List<int>>();
  final destroyed = Completer<void>();
  bool isDestroyed = false;
  EchoChannel() {
    outgoing.stream.listen((bytes) {
      if (!isDestroyed) incoming.add(Uint8List.fromList(bytes));
    }, onError: (Object _) {});
  }
  @override
  Stream<Uint8List> get stream => incoming.stream;
  @override
  StreamSink<List<int>> get sink => outgoing.sink;
  @override
  Future<void> get done => destroyed.future;
  @override
  Future<void> close() async => destroy();
  @override
  Future<void> flush() async {}
  @override
  void destroy() {
    if (isDestroyed) return;
    isDestroyed = true;
    unawaited(incoming.close());
    unawaited(outgoing.close());
    destroyed.complete();
  }
}
