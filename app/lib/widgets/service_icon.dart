import 'dart:io';

import 'package:flutter/material.dart';

/// 服务贴图：优先用户自选图片，其次内置贴图资源，无贴图则显示纯色渐变块
class ServiceIcon extends StatelessWidget {
  final String? imageAsset;
  final String? imagePath;
  final Color color;
  final double size;
  final double radius;

  const ServiceIcon({
    super.key,
    this.imageAsset,
    this.imagePath,
    required this.color,
    this.size = 48,
    this.radius = 15,
  });

  @override
  Widget build(BuildContext context) {
    Widget? img;
    if (imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync()) {
      img = Image.file(
        File(imagePath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (imageAsset != null && imageAsset!.isNotEmpty) {
      img = Image.asset(
        imageAsset!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.32), color.withOpacity(0.10)],
        ),
      ),
      child: img == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: img,
            ),
    );
  }
}
