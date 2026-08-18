import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/config.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/background.dart';
import '../widgets/glass.dart';

/// 服务器连接配置页（首次使用或修改连接信息）
class ConnectionScreen extends StatefulWidget {
  final bool editMode;
  ConnectionScreen({super.key, this.editMode = false});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final MaskTextController _password;
  late final TextEditingController _key;
  late final MaskTextController _keyPass;
  bool _useKey = false;
  bool _useSudo = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<AppState>().config;
    _host = TextEditingController(text: cfg?.host ?? '');
    _port = TextEditingController(text: (cfg?.port ?? 22).toString());
    _user = TextEditingController(text: cfg?.username ?? 'root');
    _password = MaskTextController(text: cfg?.password ?? '');
    _key = TextEditingController(text: cfg?.privateKey ?? '');
    _keyPass = MaskTextController(text: cfg?.keyPassphrase ?? '');
    _useKey = cfg?.useKey ?? false;
    _useSudo = cfg?.useSudo ?? false;
  }

  void _toggleMask(MaskTextController c) {
    setState(() {
      c.maskChar = c.maskChar.isEmpty ? '•' : '';
      c.applyMask();
    });
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    _key.dispose();
    _keyPass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_host.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('请输入服务器地址'))),
      );
      return;
    }
    final app = context.read<AppState>();
    final existing = app.config;
    final cfg = ServerConfig(
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 22,
      username: _user.text.trim(),
      password: _password.text,
      privateKey: _key.text,
      keyPassphrase: _keyPass.text,
      useKey: _useKey,
      useSudo: _useSudo,
      services: existing?.services ?? ServerConfig.defaults().services,
    );
    setState(() => _busy = true);
    final ok = await app.connectAndSave(cfg);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      if (widget.editMode) {
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('连接失败：{err}', {'err': app.connError ?? L10n.t('未知错误')}))),
      );
    }
  }

  /// 连接页大图标：设置中自定义的图标优先，否则默认图标
  Widget _logoImage(BuildContext context) {
    final p = context.read<AppState>().settings.logoImagePath;
    if (p.isNotEmpty && File(p).existsSync()) {
      return Image.file(File(p), width: 86, height: 86, fit: BoxFit.cover);
    }
    return Image.asset('assets/icon.png', width: 86, height: 86, fit: BoxFit.cover);
  }

  Widget _authChip(String label, bool selected, VoidCallback onTap) {
    // 带按钮背景的登录方式切换（遮挡背景渲染异常）
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? AppColors.violet.withOpacity(0.28)
              : AppColors.text.withOpacity(0.08),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.text : AppColors.text.withOpacity(0.7),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // 必须包一层 Material：MaterialApp 的兜底 DefaultTextStyle 自带
    // 「黄色双下划线 + monospace」（警示未放入 Material 的文字），
    // 连接页此前没有 Scaffold/Material 包裹，所有文字都被画上了黄线。
    return Material(
      type: MaterialType.transparency,
      child: GradientBackground(
        noBlur: true,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  if (widget.editMode)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.text.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.arrow_back, size: 20, color: AppColors.text),
                        ),
                      ),
                    ),
                  SizedBox(height: 22),
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: [AppColors.violet, AppColors.cyan],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _logoImage(context),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'astrbot助手',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.text,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    widget.editMode ? L10n.t('更新服务器连接信息') : L10n.t('远程管理你的 AstrBot 与 NapCat'),
                    style: TextStyle(fontSize: 12.5, color: AppColors.text.withOpacity(0.6), decoration: TextDecoration.none),
                  ),
                  SizedBox(height: 26),
                  Column(
                    children: [
                        _SimpleField(
                          controller: _host,
                          placeholder: L10n.t('服务器地址（例如 47.100.12.34）'),
                          icon: Icons.cloud,
                          keyboard: TextInputType.url,
                        ),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _SimpleField(
                                controller: _port,
                                placeholder: L10n.t('端口'),
                                icon: Icons.settings_ethernet,
                                keyboard: TextInputType.number,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _SimpleField(
                                controller: _user,
                                placeholder: L10n.t('用户名（root）'),
                                icon: Icons.person,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _authChip(L10n.t('阿里云登录'), !_useKey, () => setState(() => _useKey = false)),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _authChip(L10n.t('私钥登录'), _useKey, () => setState(() => _useKey = true)),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),
                        if (!_useKey)
                            _SimpleField(
                              controller: _password,
                              placeholder: L10n.t('密码'),
                              icon: Icons.lock,
                              suffix: IconButton(
                                icon: Icon(
                                  _password.maskChar.isEmpty
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 19,
                                  color: AppColors.text.withOpacity(0.6),
                                ),
                                onPressed: () => _toggleMask(_password),
                              ),
                            )
                          else ...[
                            _SimpleField(
                              controller: _key,
                              placeholder: L10n.t('私钥 PEM 文本'),
                              icon: Icons.key,
                              maxLines: 4,
                            ),
                            SizedBox(height: 14),
                            _SimpleField(
                              controller: _keyPass,
                              placeholder: L10n.t('私钥口令（无则留空）'),
                              icon: Icons.password,
                              suffix: IconButton(
                                icon: Icon(
                                  _keyPass.maskChar.isEmpty
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 19,
                                  color: AppColors.text.withOpacity(0.6),
                                ),
                                onPressed: () => _toggleMask(_keyPass),
                              ),
                            ),
                          ],
                          SizedBox(height: 12),
                          // sudo 行带按钮背景
                          GestureDetector(
                            onTap: () => setState(() => _useSudo = !_useSudo),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: AppColors.text.withOpacity(0.08),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _useSudo
                                          ? AppColors.violet
                                          : AppColors.text.withOpacity(0.12),
                                    ),
                                    child: _useSudo
                                        ? Icon(Icons.check, size: 14, color: AppColors.text)
                                        : null,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      L10n.t('命令前加 sudo（非 root 用户请开启）'),
                                      style: TextStyle(fontSize: 12.5, color: AppColors.text.withOpacity(0.7), decoration: TextDecoration.none),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  if (app.connError != null && app.connState == ConnState.error) ...[
                    SizedBox(height: 16),
                    GlassCard(
                      tint: AppColors.red,
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: AppColors.red, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              app.connError!,
                              style: TextStyle(fontSize: 13, color: AppColors.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 20),
                  FrostedButton(
                    label: _busy
                        ? L10n.t('连接中…')
                        : (widget.editMode ? L10n.t('保存并重新连接') : L10n.t('连接并保存')),
                    icon: Icons.link,
                    primary: true,
                    expanded: true,
                    loading: _busy,
                    onPressed: _submit,
                  ),
                  SizedBox(height: 14),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.text.withOpacity(0.06),
                    ),
                    child: Text(
                      L10n.t('连接信息仅加密保存在本机，直接通过 SSH 连接你的服务器'),
                      style: TextStyle(fontSize: 11.5, color: AppColors.text.withOpacity(0.45), decoration: TextDecoration.none),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// 极简输入框：不使用 InputDecorator 的任何装饰机制（无边框/无标签/无指示器），
/// 仅圆角底色 + 图标 + 占位文字，彻底排除装饰层渲染异常
class _SimpleField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final TextInputType? keyboard;
  final Widget? suffix;
  final int maxLines;

  const _SimpleField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.keyboard,
    this.suffix,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.text.withOpacity(0.06),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 3 : 0),
            child: Icon(icon, size: 20, color: AppColors.text.withOpacity(0.6)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              maxLines: maxLines,
              obscureText: false,
              // 不关闭建议/纠错：避免被系统判定为"安全字段"而弹安全键盘
              style: TextStyle(fontSize: 15, color: AppColors.text, decoration: TextDecoration.none),
              decoration: InputDecoration.collapsed(
                hintText: placeholder,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.text.withOpacity(0.35),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}
