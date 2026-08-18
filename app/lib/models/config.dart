import 'dart:ui' show Color;

import '../l10n.dart';

/// 服务管理方式
enum ServiceKind { container, compose, systemd }

extension ServiceKindX on ServiceKind {
  String get label {
    switch (this) {
      case ServiceKind.container:
        return L10n.t('Docker 容器');
      case ServiceKind.compose:
        return L10n.t('Docker Compose');
      case ServiceKind.systemd:
        return L10n.t('systemd 服务');
    }
  }

  String get shortLabel {
    switch (this) {
      case ServiceKind.container:
        return L10n.t('容器');
      case ServiceKind.compose:
        return L10n.t('Compose');
      case ServiceKind.systemd:
        return L10n.t('systemd');
    }
  }
}

/// 单个受管服务（AstrBot / NapCat / 任意自定义服务）
class ServiceConfig {
  final String id;
  String name;
  String target;
  ServiceKind kind;
  String composeFile;
  String emoji;
  int colorValue;
  int webuiPort;
  String webuiPath;

  /// 内置贴图资源路径（如 assets/services/astrbot.png），自定义服务为 null
  String? imageAsset;

  /// 用户自选贴图文件路径（服务编辑器内更换）
  String? imagePath;

  ServiceConfig({
    required this.id,
    required this.name,
    required this.target,
    this.kind = ServiceKind.container,
    this.composeFile = '',
    this.emoji = '',
    this.colorValue = 0xFF8B7CFF,
    this.webuiPort = 6185,
    this.webuiPath = '',
    this.imageAsset,
    this.imagePath,
  });

  Color get color => Color(colorValue);

  factory ServiceConfig.fromJson(Map<String, dynamic> j) {
    return ServiceConfig(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? L10n.t('服务'),
      target: j['target'] as String? ?? '',
      kind: ServiceKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => ServiceKind.container,
      ),
      composeFile: j['composeFile'] as String? ?? '',
      emoji: j['emoji'] as String? ?? '',
      colorValue: j['colorValue'] as int? ?? 0xFF8B7CFF,
      webuiPort: j['webuiPort'] as int? ?? 6185,
      webuiPath: j['webuiPath'] as String? ?? '',
      imageAsset: j['imageAsset'] as String?,
      imagePath: j['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'kind': kind.name,
        'composeFile': composeFile,
        'emoji': emoji,
        'colorValue': colorValue,
        'webuiPort': webuiPort,
        'webuiPath': webuiPath,
        'imageAsset': imageAsset,
        'imagePath': imagePath,
      };
}

/// 服务器连接配置
class ServerConfig {
  String host;
  int port;
  String username;
  String password;
  String privateKey;
  String keyPassphrase;
  bool useKey;
  bool useSudo;
  List<ServiceConfig> services;

  ServerConfig({
    required this.host,
    required this.port,
    required this.username,
    this.password = '',
    this.privateKey = '',
    this.keyPassphrase = '',
    this.useKey = false,
    this.useSudo = false,
    required this.services,
  });

  factory ServerConfig.defaults() {
    return ServerConfig(
      host: '',
      port: 22,
      username: 'root',
      services: [
        ServiceConfig(
          id: 'astrbot',
          name: 'AstrBot',
          target: 'astrbot',
          colorValue: 0xFF4FD8EB,
          webuiPort: 6185,
          imageAsset: 'assets/services/astrbot.png',
        ),
        ServiceConfig(
          id: 'napcat',
          name: 'NapCat',
          target: 'napcat',
          colorValue: 0xFFFF7AC6,
          webuiPort: 6099,
          imageAsset: 'assets/services/napcat.png',
        ),
      ],
    );
  }

  factory ServerConfig.fromJson(Map<String, dynamic> j) {
    return ServerConfig(
      host: j['host'] as String? ?? '',
      port: j['port'] as int? ?? 22,
      username: j['username'] as String? ?? 'root',
      password: j['password'] as String? ?? '',
      privateKey: j['privateKey'] as String? ?? '',
      keyPassphrase: j['keyPassphrase'] as String? ?? '',
      useKey: j['useKey'] as bool? ?? false,
      useSudo: j['useSudo'] as bool? ?? false,
      services: ((j['services'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ServiceConfig.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'privateKey': privateKey,
        'keyPassphrase': keyPassphrase,
        'useKey': useKey,
        'useSudo': useSudo,
        'services': services.map((s) => s.toJson()).toList(),
      };
}
