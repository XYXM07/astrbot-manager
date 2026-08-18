import 'package:flutter/services.dart';

/// 应用刷新率/帧率控制（由原生 MainActivity 的 MethodChannel 实现）
class FrameRateService {
  static const MethodChannel _channel = MethodChannel('astr/frame_rate');

  /// fps：30 / 60 / 120；0 表示无限制（跟随系统默认）
  static Future<void> apply(int fps) async {
    try {
      await _channel.invokeMethod<void>('setFrameRate', fps);
    } catch (_) {
      // 设备不支持时静默忽略
    }
  }
}
