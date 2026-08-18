import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// 渐变背景 + 可选自定义图片 + 页面级单层毛玻璃模糊
class GradientBackground extends StatelessWidget {
  final Widget child;

  /// 强制关闭本页模糊层（用于排查 GPU 模糊伪影，如连接页的黄条）
  final bool noBlur;

  const GradientBackground({super.key, required this.child, this.noBlur = false});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final imgPath = settings.backgroundImagePath;
    final hasImage = imgPath.isNotEmpty && File(imgPath).existsSync();
    final blurOn = settings.blurEnabled && !noBlur;
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom, AppColors.bgThird],
          ),
        ),
        child: Stack(
          children: [
            if (hasImage)
              Positioned.fill(
                child: Image.file(
                  File(imgPath),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            // 压暗图片保证文字可读（浅色模式压暗更轻）
            if (hasImage)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(AppColors.light ? 0.15 : 0.55),
                ),
              ),
            // 页面级单层毛玻璃模糊：位于背景与内容之间
            if (blurOn)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: settings.blurSigma,
                    sigmaY: settings.blurSigma,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
