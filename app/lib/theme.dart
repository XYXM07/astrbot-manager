import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用配色（随浅色/深色模式自适应）
class AppColors {
  /// 当前是否浅色模式（由入口在构建前设置）
  static bool light = false;

  /// 主文字色
  static Color get text => light ? const Color(0xFF1E2235) : Colors.white;

  /// 背景渐变（上/中/下）
  static Color get bgTop => light ? const Color(0xFFE9EBF8) : const Color(0xFF0B0E1E);
  static Color get bgBottom => light ? const Color(0xFFDCE0F4) : const Color(0xFF17123B);
  static Color get bgThird => light ? const Color(0xFFF2F4FC) : const Color(0xFF0C0822);

  /// 底部菜单/浮层面板底色
  static Color get panel => light ? const Color(0xF2FFFFFF) : const Color(0xF21A1E3A);

  /// 强调面板（导航栏/快照栏/悬浮按钮）
  static Color get panelStrong => light ? const Color(0xF7FFFFFF) : const Color(0xE61C2148);

  /// 终端背景与文字
  static Color get terminalBg => light ? const Color(0xF7FFFFFF) : const Color(0xE60A0D18);
  static Color get terminalText => light ? const Color(0xFF14532D) : const Color(0xFFC9F0D8);

  // 品牌色（深浅模式通用）
  static const violet = Color(0xFF8B7CFF);
  static const cyan = Color(0xFF4FD8EB);
  static const pink = Color(0xFFFF7AC6);
  static const green = Color(0xFF4ADE80);
  static const red = Color(0xFFF87171);
  static const amber = Color(0xFFFBBF24);
  static const gray = Color(0xFF94A3B8);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: AppColors.light ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: AppColors.light ? Brightness.light : Brightness.dark,
    ),
    // 禁用系统焦点/悬停/水波高亮（部分 OEM 主题会注入黄色高亮横条）
    focusColor: Colors.transparent,
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      // 固定字体族，避免部分机型自定义字体主题引发异常渲染
      fontFamily: 'sans-serif',
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.text,
      systemOverlayStyle: AppColors.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.panelStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentTextStyle: TextStyle(color: AppColors.text, fontSize: 14),
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    // 光标/选区颜色显式指定为品牌紫，杜绝 OEM 主题注入异常选区/光标颜色
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.violet,
      selectionColor: AppColors.violet.withOpacity(0.35),
      selectionHandleColor: AppColors.violet,
    ),
    // 全部输入框统一为圆角无描边样式，任何情况下都不显示线条
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.text.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: TextStyle(color: AppColors.text.withOpacity(0.65)),
      hintStyle: TextStyle(color: AppColors.text.withOpacity(0.35), fontSize: 12.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
