import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/image_utils.dart';
import '../widgets/background.dart';
import '../widgets/glass.dart';

/// APP 设置页
class SettingsScreen extends StatefulWidget {
  SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _pickBackground() async {
    final app = context.read<AppState>();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2160,
        maxHeight: 3840,
        imageQuality: 90,
      );
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final dest = '${dir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(dest);
      if (!mounted) return;
      await app.updateSettings(
        app.settings.copyWith(backgroundImagePath: dest),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('背景已更新'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('选择图片失败：{err}', {'err': '$e'}))),
        );
      }
    }
  }

  /// 更换顶部界面图标（仅接受 1:1 比例图片）
  Future<void> _pickLogo() async {
    final app = context.read<AppState>();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 92,
      );
      if (picked == null) return;
      final bytes = await File(picked.path).readAsBytes();
      final img = await decodeImage(bytes);
      if (img.width != img.height) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.t('请选择 1:1 比例的图片'))),
          );
        }
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final dest =
          '${dir.path}/logo_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(picked.path).copy(dest);
      if (!mounted) return;
      await app.updateSettings(
        app.settings.copyWith(logoImagePath: dest),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('界面图标已更新'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('选择图片失败：{err}', {'err': '$e'}))),
        );
      }
    }
  }

  Future<void> _clearBackground() async {
    final app = context.read<AppState>();
    await app.updateSettings(      app.settings.copyWith(backgroundImagePath: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    final hasImage = s.backgroundImagePath.isNotEmpty;
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              _sectionTitle(L10n.t('背景')),
              GlassCard(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.t('自定义背景图片'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.text.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      hasImage ? L10n.t('已使用自定义背景') : L10n.t('当前使用默认渐变背景'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.text.withOpacity(0.45),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FrostedButton(
                            label: L10n.t('选择图片'),
                            icon: Icons.photo_library,
                            primary: true,
                            onPressed: _pickBackground,
                          ),
                        ),
                        if (hasImage) ...[
                          SizedBox(width: 10),
                          Expanded(
                            child: FrostedButton(
                              label: L10n.t('恢复默认'),
                              icon: Icons.restore,
                              onPressed: _clearBackground,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      L10n.t('界面图标（顶部）'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.text.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      L10n.t('仅接受 1:1 比例的图片'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.text.withOpacity(0.45),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FrostedButton(
                            label: L10n.t('更换图标'),
                            icon: Icons.image,
                            onPressed: _pickLogo,
                          ),
                        ),
                        if (s.logoImagePath.isNotEmpty) ...[
                          SizedBox(width: 10),
                          Expanded(
                            child: FrostedButton(
                              label: L10n.t('恢复默认'),
                              icon: Icons.restore,
                              onPressed: () => app.updateSettings(
                                s.copyWith(logoImagePath: ''),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _sectionTitle(L10n.t('显示')),
              GlassCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    _switchRow(
                      title: L10n.t('毛玻璃背景模糊'),
                      subtitle: L10n.t('整页单层模糊，滚动稳定且流畅'),
                      value: s.blurEnabled,
                      onChanged: (v) =>
                          app.updateSettings(s.copyWith(blurEnabled: v)),
                    ),
                    _switchRow(
                      title: L10n.t('浅色模式'),
                      subtitle: L10n.t('全局切换为浅色界面'),
                      value: s.lightMode,
                      onChanged: (v) =>
                          app.updateSettings(s.copyWith(lightMode: v)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L10n.t('语言'),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.text.withOpacity(0.85),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            L10n.t('切换界面显示语言，立即生效'),
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: AppColors.text.withOpacity(0.45),
                            ),
                          ),
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              _chip(
                                '中文',
                                s.language != 'en',
                                () => app.updateSettings(
                                  s.copyWith(language: 'zh'),
                                ),
                              ),
                              _chip(
                                'English',
                                s.language == 'en',
                                () => app.updateSettings(
                                  s.copyWith(language: 'en'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                L10n.t('模糊强度'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.text.withOpacity(0.85),
                                ),
                              ),
                              Spacer(),
                              Text(
                                s.blurSigma.round().toString(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.text.withOpacity(0.55),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: s.blurSigma.clamp(8.0, 28.0).toDouble(),
                            min: 8,
                            max: 28,
                            divisions: 10,
                            activeColor: AppColors.violet,
                            inactiveColor: AppColors.text.withOpacity(0.2),
                            onChanged: s.blurEnabled
                                ? (v) => app.updateSettings(
                                    s.copyWith(blurSigma: v))
                                : null,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L10n.t('刷新率（帧率）'),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.text.withOpacity(0.85),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            L10n.t('按应用锁定帧率，切换后立即生效；无限制则跟随系统'),
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: AppColors.text.withOpacity(0.45),
                            ),
                          ),
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final opt in [30, 60, 120, 0])
                                _chip(
                                  opt == 0 ? L10n.t('无限制') : '$opt',
                                  s.frameRate == opt,
                                  () => app.updateSettings(
                                    s.copyWith(frameRate: opt),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _sectionTitle(L10n.t('管理')),
              GlassCard(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.t('状态自动刷新'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.text.withOpacity(0.85),
                      ),
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final opt in [0, 30, 60, 120])
                          _chip(
                            opt == 0
                                ? L10n.t('关闭')
                                : L10n.t('{n} 秒', {'n': '$opt'}),
                            s.autoRefreshSeconds == opt,
                            () => app.updateSettings(
                              s.copyWith(autoRefreshSeconds: opt),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 18),
                    Text(
                      L10n.t('日志默认行数'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.text.withOpacity(0.85),
                      ),
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final opt in [100, 200, 500])
                          _chip(
                            L10n.t('{n} 行', {'n': '$opt'}),
                            s.logLines == opt,
                            () => app.updateSettings(
                              s.copyWith(logLines: opt),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          L10n.t('日志字号'),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.text.withOpacity(0.85),
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${s.logFontSize.round()}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.text.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: s.logFontSize.clamp(10.0, 24.0).toDouble(),
                      min: 10,
                      max: 24,
                      divisions: 14,
                      activeColor: AppColors.violet,
                      inactiveColor: AppColors.text.withOpacity(0.2),
                      onChanged: (v) =>
                          app.updateSettings(s.copyWith(logFontSize: v)),
                    ),
                  ],
                ),
              ),
              _sectionTitle(L10n.t('关于')),
              GlassCard(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('astrbot助手', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                        Spacer(),
                        Text(
                          'v1.0.0',
                          style: TextStyle(fontSize: 12.5, color: AppColors.text.withOpacity(0.55)),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      L10n.t('作者：星月晓梦_07'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text.withOpacity(0.75),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      L10n.t('通过 SSH 直连远程管理服务器上的 AstrBot 与 NapCat。连接凭据仅加密保存在本机，所有操作经 SSH 加密传输。'),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: AppColors.text.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 18, 6, 10),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.text.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    // 带本地动画状态的开关行：切换时先本地播放动画，再应用设置
    // （避免设置生效触发全页重绘，导致开关动画卡掉）
    return _AnimatedSwitchRow(
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.violet.withOpacity(0.22)
              : AppColors.text.withOpacity(0.06),
          border: Border.all(
            color: selected
                ? AppColors.violet.withOpacity(0.55)
                : AppColors.text.withOpacity(0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.text : AppColors.text.withOpacity(0.65),
          ),
        ),
      ),
    );
  }
}

/// 带本地动画状态的开关行：先本地播放开关动画，延迟后再应用设置，
/// 避免设置生效引发全页重绘把动画卡掉
class _AnimatedSwitchRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  _AnimatedSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_AnimatedSwitchRow> createState() => _AnimatedSwitchRowState();
}

class _AnimatedSwitchRowState extends State<_AnimatedSwitchRow> {
  bool _v = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AnimatedSwitchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部变化（非本开关触发）时同步
    if (_timer == null && oldWidget.value != widget.value) {
      setState(() => _v = widget.value);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle(bool v) {
    setState(() => _v = v); // 先本地切换，播放动画
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: 280), () {
      _timer = null;
      widget.onChanged(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.text.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.text.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Switch(
            value: _v,
            activeTrackColor: AppColors.violet.withOpacity(0.6),
            activeColor: AppColors.violet,
            onChanged: _toggle,
          ),
        ],
      ),
    );
  }
}
