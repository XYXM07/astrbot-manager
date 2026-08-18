import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 解码图片（decodeImageFromList 的回调封装为 Future）
Future<ui.Image> decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, (img) {
    if (!completer.isCompleted) completer.complete(img);
  });
  return completer.future;
}
