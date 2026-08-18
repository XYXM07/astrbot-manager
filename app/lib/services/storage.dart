import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/config.dart';
import '../models/settings.dart';

/// 配置持久化：使用系统安全存储（Android Keystore 加密）
class StorageService {
  static const _key = 'astrbot_manager_v1';
  static const _settingsKey = 'astrbot_settings_v1';
  const StorageService();

  final FlutterSecureStorage _store = const FlutterSecureStorage();

  Future<ServerConfig?> load() async {
    try {
      final raw = await _store.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return ServerConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ServerConfig cfg) async {
    await _store.write(key: _key, value: jsonEncode(cfg.toJson()));
  }

  Future<AppSettings> loadSettings() async {
    try {
      final raw = await _store.read(key: _settingsKey);
      if (raw == null || raw.isEmpty) return AppSettings();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return AppSettings();
      // v1.13 起默认浅色：旧配置（无 frameRate 字段）迁移一次为浅色，
      // 用户之后手动切换的深浅会被正常保存
      final isOld = !json.containsKey('frameRate');
      final s = AppSettings.fromJson(json);
      if (isOld) {
        s.lightMode = true;
        await _store.write(key: _settingsKey, value: jsonEncode(s.toJson()));
      }
      return s;
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) async {
    await _store.write(key: _settingsKey, value: jsonEncode(s.toJson()));
  }
}
