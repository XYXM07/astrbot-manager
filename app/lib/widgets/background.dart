import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'motion.dart';

/// One stationary background shared by nested tab pages. Only the background
/// image is blurred; native WebViews never enter a backdrop filter.
class GradientBackground extends StatelessWidget {
  final Widget child;

  /// 强制关闭本页模糊层（用于排查 GPU 模糊伪影，如连接页的黄条）
  final bool noBlur;

  const GradientBackground({
    super.key,
    required this.child,
    this.noBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<_BackgroundScope>() !=
        null) {
      return child;
    }
    final settings = context.watch<AppState>().settings;
    final imgPath = settings.backgroundImagePath;
    final hasImage = imgPath.isNotEmpty && File(imgPath).existsSync();
    final blurOn = settings.blurEnabled && !noBlur;
    Widget backdrop = AnimatedContainer(
      key: const ValueKey('shared-background'),
      duration: AppMotion.duration(context, AppMotion.page),
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bgBottom, AppColors.bgThird],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
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
                color: Colors.black.withOpacity(
                  AppColors.light ? 0.15 : 0.55,
                ),
              ),
            ),
        ],
      ),
    );
    backdrop = ImageFiltered(
      enabled: blurOn,
      imageFilter: ImageFilter.blur(
        sigmaX: settings.blurSigma,
        sigmaY: settings.blurSigma,
        tileMode: TileMode.clamp,
      ),
      child: backdrop,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: ClipRect(child: backdrop)),
          ),
        ),
        _BackgroundScope(child: child),
      ],
    );
  }
}

class _BackgroundScope extends InheritedWidget {
  const _BackgroundScope({required super.child});

  @override
  bool updateShouldNotify(_BackgroundScope oldWidget) => false;
}
