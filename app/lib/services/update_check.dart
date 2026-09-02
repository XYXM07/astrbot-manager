import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../version.dart';

/// 新版本信息
class UpdateInfo {
  final String version;
  final String? apkUrl;
  final String? notes;

  const UpdateInfo({required this.version, this.apkUrl, this.notes});
}

/// 通过 GitHub Releases 检查更新（astrbot助手 的发布源）
class UpdateService {
  static const String repo = 'XYXM07/astrbot-manager';

  /// 检查是否有新版本；无新版本返回 null，网络失败抛异常
  static Future<UpdateInfo?> check() async {
    final url =
        'https://api.github.com/repos/$repo/releases/latest';
    final resp = await http
        .get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'astrbot-assistant/$appVersion',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String?) ?? '';
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (version.isEmpty || compareVersion(version, appVersion) <= 0) {
      return null;
    }
    String? apkUrl;
    for (final a in ((data['assets'] as List?) ?? const []).whereType<Map<String, dynamic>>()) {
      final name = (a['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apkUrl = (a['browser_download_url'] as String?) ?? apkUrl;
      }
    }
    apkUrl ??= (data['html_url'] as String?) ?? '';
    final body = (data['body'] as String?) ?? '';
    return UpdateInfo(
      version: version,
      apkUrl: apkUrl!.isEmpty ? null : apkUrl,
      notes: body.trim().isEmpty ? null : body.trim(),
    );
  }

  /// 比较 x.y.z 版本号：a > b 返回正数，相等返回 0
  static int compareVersion(String a, String b) {
    final pa = a.split(RegExp(r'[.\-]')).map(int.tryParse).whereType<int>().toList();
    final pb = b.split(RegExp(r'[.\-]')).map(int.tryParse).whereType<int>().toList();
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }
}
