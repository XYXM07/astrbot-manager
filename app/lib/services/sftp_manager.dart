import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../l10n.dart';
import 'ssh.dart';

/// 远程文件条目（SFTP 目录列表）
class RemoteFile {
  final String name;
  final String path;
  final bool isDir;
  final int? size;
  final int? mtime; // 秒级时间戳
  const RemoteFile({
    required this.name,
    required this.path,
    required this.isDir,
    this.size,
    this.mtime,
  });
}

/// 远程文件管理（基于同一 SSH 连接的 SFTP）
class SftpManager {
  final SshService ssh;
  SftpManager(this.ssh);

  SftpClient? _sftp;

  Future<SftpClient> _client() async {
    final c = _sftp;
    if (c != null) return c;
    final sshc = ssh.client;
    if (sshc == null || sshc.isClosed) {
      throw SshException(L10n.t('尚未连接服务器'));
    }
    final s = await sshc.sftp();
    _sftp = s;
    return s;
  }

  Future<void> close() async {
    try {
      await _sftp?.close();
    } catch (_) {}
    _sftp = null;
  }

  String join(String dir, String name) =>
      dir == '/' ? '/$name' : '$dir/$name';

  /// 列出目录内容（排除 . 和 ..，解析符号链接目标类型）
  Future<List<RemoteFile>> list(String dir) async {
    final s = await _client();
    final names = await s.listdir(dir);
    final out = <RemoteFile>[];
    for (final n in names) {
      final name = n.filename;
      if (name == '.' || name == '..') continue;
      var isDir = n.attr.isDirectory;
      // 符号链接：跟随解析真实类型
      if (!isDir && n.attr.mode?.type == SftpFileType.symbolicLink) {
        try {
          isDir = (await s.stat(join(dir, name))).isDirectory;
        } catch (_) {}
      }
      out.add(RemoteFile(
        name: name,
        path: join(dir, name),
        isDir: isDir,
        size: n.attr.size,
        mtime: n.attr.modifyTime,
      ));
    }
    return out;
  }

  /// 删除文件或空目录（自动识别）
  Future<void> delete(String path) async {
    final s = await _client();
    try {
      await s.remove(path);
    } catch (_) {
      await s.rmdir(path);
    }
  }

  Future<void> rename(String from, String to) async {
    final s = await _client();
    await s.rename(from, to);
  }

  Future<void> mkdir(String path) async {
    final s = await _client();
    await s.mkdir(path);
  }

  /// 读取文件全部内容（上限保护由调用方负责）
  Future<Uint8List> readBytes(String path, {int? length}) async {
    final s = await _client();
    final f = await s.open(path, mode: SftpFileOpenMode.read);
    try {
      return await f.readBytes(length: length);
    } finally {
      await f.close();
    }
  }

  /// 写入文件（覆盖）
  Future<void> writeBytes(String path, Uint8List data) async {
    final s = await _client();
    final f = await s.open(
      path,
      mode: SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      await f.writeBytes(data);
    } finally {
      await f.close();
    }
  }

  /// 复制文件（整读整写，调用方需限制大小）
  Future<void> copy(String from, String to) async {
    final data = await readBytes(from);
    await writeBytes(to, data);
  }
}
