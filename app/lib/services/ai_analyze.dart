import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// AI 日志分析：调用 OpenAI 兼容的 chat/completions 接口
/// （DeepSeek / 通义千问 / Moonshot / OpenAI 等均可）
class AiAnalyzeService {
  static const String _systemPrompt =
      '你是一名资深运维工程师，擅长排查 AstrBot 与 NapCat 及相关服务的日志。'
      '请用简体中文简洁地回答：日志中的错误原因、影响范围，以及具体的修复建议。'
      '如果日志中没有明显错误，请说明当前日志看起来正常。';

  /// 分析一段日志/文本，返回 AI 回复内容
  static Future<String> analyze({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String content,
  }) async {
    final url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions';
    final resp = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {'role': 'user', 'content': '以下是服务日志：\n\n$content'},
            ],
            'temperature': 0.3,
            'max_tokens': 1500,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}\n${resp.body}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('接口返回中没有 choices');
    }
    final msg = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>?;
    final text = (msg?['content'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      throw Exception('接口返回内容为空');
    }
    return text;
  }
}
