import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';

/// 毛玻璃卡片：半透明渐变 + 高光描边
/// 背景模糊默认由页面级单层模糊提供；[backdropSigma] 非空时卡片自身
/// 追加一层高强模糊（用于二级菜单，防止与下层内容视觉重叠）
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final VoidCallback? onTap;
  final bool borderless;
  final double? backdropSigma;

   GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.tint,
    this.onTap,
    this.borderless = false,
    this.backdropSigma,
  });

  @override
  Widget build(BuildContext context) {
    // 玻璃底色始终使用白色光晕（浅色模式下同样呈现白色玻璃而非黑色）
    final base = tint ?? Colors.white;
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base.withOpacity(0.13), base.withOpacity(0.05)],
            ),
            border: borderless
                ? null
                : Border.all(color: AppColors.text.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(AppColors.light ? 0.06 : 0.28),
                blurRadius: AppColors.light ? 18 : 34,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
    final card = ClipRRect(borderRadius: BorderRadius.circular(radius), child: content);
    // 二级菜单专用：高强度背景模糊，防止与下层内容视觉重叠
    if (backdropSigma != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: backdropSigma!, sigmaY: backdropSigma!),
          child: card,
        ),
      );
    }
    return card;
  }
}

/// 毛玻璃按钮：primary 为渐变填充，否则为描边玻璃样式
class FrostedButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;
  final bool expanded;
  final Color? color;

  FrostedButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.loading = false,
    this.expanded = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.violet;
    final enabled = onPressed != null && !loading;

    final Widget inner = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? AppColors.text : accent,
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 17, color: AppColors.text.withOpacity(0.95)),
          SizedBox(width: 7),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.text.withOpacity(0.94),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );

    final Widget button = primary
        ? Container(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: [AppColors.violet, AppColors.cyan]),
            ),
            child: inner,
          )
        : Container(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.text.withOpacity(0.08),
              border: Border.all(color: AppColors.text.withOpacity(0.22)),
            ),
            child: inner,
          );

    return SizedBox(
      width: expanded ? double.infinity : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: GestureDetector(onTap: enabled ? onPressed : null, child: button),
      ),
    );
  }
}

/// 状态胶囊：发光圆点 + 状态文字
class StatusPill extends StatelessWidget {
  final String state;
  StatusPill({super.key, required this.state});

  Color get _color {
    switch (state) {
      case 'running':
      case 'active':
        return AppColors.green;
      case 'restarting':
        return AppColors.amber;
      case 'exited':
      case 'error':
      case 'failed':
        return AppColors.red;
      case 'created':
      case 'paused':
      case 'dead':
        return AppColors.amber;
      case 'missing':
      case 'inactive':
        return AppColors.gray;
      default:
        return AppColors.gray;
    }
  }

  String get _label {
    switch (state) {
      case 'running':
      case 'active':
        return L10n.t('运行中');
      case 'restarting':
        return L10n.t('重启中');
      case 'exited':
        return L10n.t('已停止');
      case 'error':
        return L10n.t('出错');
      case 'missing':
        return L10n.t('未找到');
      case 'created':
        return L10n.t('未启动');
      case 'paused':
        return L10n.t('已暂停');
      case 'dead':
        return L10n.t('异常');
      case 'inactive':
        return L10n.t('未运行');
      case 'failed':
        return L10n.t('失败');
      default:
        return state;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.text.withOpacity(0.07),
        border: Border.all(color: AppColors.text.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              boxShadow: [BoxShadow(color: c.withOpacity(0.9), blurRadius: 8)],
            ),
          ),
          SizedBox(width: 7),
          Text(
            _label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// 毛玻璃输入框
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboard;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final Widget? suffix;
  final int maxLines;
  final String? Function(String?)? validator;

  /// 手动遮挡模式：不声明为密码类型（彻底避免系统安全键盘），由 MaskTextController 渲染圆点
  final bool masked;

  GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboard,
    this.obscure = false,
    this.onToggleObscure,
    this.suffix,
    this.maxLines = 1,
    this.validator,
    this.masked = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: masked ? false : obscure,
      maxLines: maxLines,
      // 密码字段使用 visiblePassword 类型，避免触发手机安全键盘（及其黄色指示条）
      keyboardType: masked
          ? TextInputType.text
          : (obscure ? TextInputType.visiblePassword : keyboard),
      validator: validator,
      // 不关闭建议/纠错：避免被系统判定为"安全字段"而弹安全键盘
      style: TextStyle(fontSize: 15, decoration: TextDecoration.none),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.text.withOpacity(0.6)),
        suffixIcon: suffix ??
            (onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      size: 19,
                      color: AppColors.text.withOpacity(0.6),
                    ),
                    onPressed: onToggleObscure,
                  )
                : null),
        filled: true,
        fillColor: AppColors.text.withOpacity(0.06),
        labelStyle: TextStyle(color: AppColors.text.withOpacity(0.65)),
        hintStyle: TextStyle(color: AppColors.text.withOpacity(0.35), fontSize: 12.5),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        // 全部使用无描边圆角（无任何线条，避免黄线现象）
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
}

/// 毛玻璃底部菜单外壳：高强度背景模糊（sigma 36），
/// 二级菜单打开时模糊掉下层内容，防止视觉重叠
class FrostedSheet extends StatelessWidget {
  final Widget child;
  const FrostedSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 手动遮挡密码的控制器：字段不声明为密码类型（避免触发系统安全键盘），
/// 渲染时将文字替换为圆点；[maskChar] 设为空字符串可临时显示明文。
class MaskTextController extends TextEditingController {
  MaskTextController({super.text});

  String maskChar = '•';

  /// 切换遮挡状态后调用，通知输入框重绘
  void applyMask() => notifyListeners();

  int _c(int v) => v.clamp(0, text.length).toInt();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // 明文模式：显示真实文字
    if (maskChar.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final masked = maskChar * text.length;
    if (!withComposing || !value.composing.isValid) {
      return TextSpan(style: style, text: masked);
    }
    final c = value.composing;
    final s = _c(c.start);
    final e = _c(c.end);
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: masked.substring(0, s)),
        TextSpan(
          text: masked.substring(s, e),
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
        TextSpan(text: masked.substring(e)),
      ],
    );
  }
}
