import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n.dart';
import '../models/config.dart';
import '../services/webui_session.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/background.dart';
import '../widgets/glass.dart';
import '../widgets/service_icon.dart';

/// WebUI 页：多会话（多开）管理，会话在切换底部标签后保持存活
class WebUiSessionsPage extends StatelessWidget {
  WebUiSessionsPage({super.key});

  Future<void> _openNew(BuildContext context) async {
    final app = context.read<AppState>();
    final cfg = app.config;
    if (cfg == null || cfg.services.isEmpty) return;
    final picked = await showModalBottomSheet<ServiceConfig>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FrostedSheet(child: _ServicePicker(services: cfg.services)),
    );
    if (picked != null && context.mounted) {
      context.read<AppState>().openWebuiSession(picked);
    }
  }

  /// 打开自定义网址会话（直连，无需 SSH 隧道）
  Future<void> _openCustom(BuildContext context) async {
    final url = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => const _CustomUrlDialog(),
    );
    if (url != null && url.isNotEmpty && context.mounted) {
      context.read<AppState>().openCustomWebui(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = app.webuiSessions;
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: sessions.isEmpty
              ? _emptyState(context)
              : Column(
                  children: [
                    // 会话切换标签 + 打开新会话按钮
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.only(left: 14),
                              itemCount: sessions.length,
                              itemBuilder: (context, i) {
                                final s = sessions[i];
                                return Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => app.selectWebuiSession(i),
                                    child: Container(
                                      padding: EdgeInsets.only(
                                        left: 14,
                                        right: 6,
                                        top: 8,
                                        bottom: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: i == app.webuiActiveIndex
                                            ? AppColors.violet.withOpacity(0.24)
                                            : AppColors.text.withOpacity(0.06),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            s.label,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: i == app.webuiActiveIndex
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => app.closeWebuiSession(i),
                                            child: Padding(
                                              padding: EdgeInsets.all(3),
                                              child: Icon(
                                                Icons.close,
                                                size: 15,
                                                color: AppColors.text.withOpacity(0.7),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, size: 22, color: AppColors.text),
                            tooltip: L10n.t('打开 WebUI'),
                            onPressed: () => _openNew(context),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, size: 20, color: AppColors.text),
                            tooltip: L10n.t('重新加载页面'),
                            onPressed: () {
                              if (app.webuiActiveIndex >= 0 &&
                                  app.webuiActiveIndex < sessions.length) {
                                sessions[app.webuiActiveIndex].reloadPage();
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.add_link, size: 21, color: AppColors.text),
                            tooltip: L10n.t('自定义网址'),
                            onPressed: () => _openCustom(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: app.webuiActiveIndex,
                        children: [
                          for (var i = 0; i < sessions.length; i++)
                            _SessionView(session: sessions[i], index: i),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, size: 40, color: AppColors.violet),
            SizedBox(height: 10),
            Text(
              L10n.t('还没有打开的 WebUI'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            SizedBox(height: 6),
            Text(
              L10n.t('通过 SSH 隧道安全访问 AstrBot / NapCat 后台，\n可同时打开多个会话'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.text.withOpacity(0.55)),
            ),
            SizedBox(height: 14),
            FrostedButton(
              label: L10n.t('打开 WebUI'),
              icon: Icons.language,
              primary: true,
              onPressed: () => _openNew(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个会话视图
class _SessionView extends StatelessWidget {
  final WebUiSession session;
  final int index;
  _SessionView({required this.session, required this.index});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.error != null) {
          return Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: GlassCard(
                tint: AppColors.red,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error, color: AppColors.red, size: 30),
                    SizedBox(height: 12),
                    Text(
                      L10n.t('无法打开 {name} 的 WebUI\n\n{err}', {'name': session.service.name, 'err': session.error ?? ''}),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.text),
                    ),
                    SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FrostedButton(
                          label: L10n.t('重试'),
                          icon: Icons.refresh,
                          color: AppColors.red,
                          onPressed: session.start,
                        ),
                        SizedBox(width: 10),
                        FrostedButton(
                          label: L10n.t('关闭会话'),
                          icon: Icons.close,
                          onPressed: () => app.closeWebuiSession(index),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final c = session.controller;
        if (c == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.violet),
                SizedBox(height: 14),
                Text(
                  session.directUrl != null
                      ? L10n.t('正在打开 {name}…', {'name': session.label})
                      : L10n.t('正在通过 SSH 隧道连接 {name}…', {'name': session.service.name}),
                  style: TextStyle(fontSize: 13, color: AppColors.text.withOpacity(0.7)),
                ),
              ],
            ),
          );
        }
        return Stack(
          children: [
            WebViewWidget(controller: c),
            if (session.connecting)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.violet,
                  backgroundColor: Colors.transparent,
                ),
              ),
            if (session.pageError != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppColors.panel,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: AppColors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.pageError!,
                          style: TextStyle(fontSize: 12.5, color: AppColors.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: session.start,
                        child: Text(L10n.t('重试'), style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ServicePicker extends StatelessWidget {
  final List<ServiceConfig> services;
  _ServicePicker({required this.services});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 12),
            child: Text(
              L10n.t('选择要打开 WebUI 的服务'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: services.length,
              itemBuilder: (context, i) {
                final s = services[i];
                return ListTile(
                  leading: ServiceIcon(
                    imageAsset: s.imageAsset,
                    imagePath: s.imagePath,
                    color: s.color,
                    size: 36,
                    radius: 10,
                  ),
                  title: Text(
                    s.name,
                    style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    L10n.t('端口 {port}', {'port': '${s.webuiPort}'}),
                    style: TextStyle(color: AppColors.text.withOpacity(0.54), fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right, color: AppColors.text.withOpacity(0.54)),
                  onTap: () => Navigator.of(context).pop(s),
                );
              },
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 自定义网址输入对话框（直连打开，无需 SSH 隧道）
class _CustomUrlDialog extends StatefulWidget {
  const _CustomUrlDialog();

  @override
  State<_CustomUrlDialog> createState() => _CustomUrlDialogState();
}

class _CustomUrlDialogState extends State<_CustomUrlDialog> {
  final TextEditingController _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final u = _url.text.trim();
    if (u.isEmpty ||
        !(u.startsWith('http://') || u.startsWith('https://'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('请输入要打开的网址（以 http:// 或 https:// 开头）'))),
      );
      return;
    }
    Navigator.of(context).pop(u);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 28),
      child: GlassCard(
        tint: AppColors.violet,
        backdropSigma: 36,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.t('自定义网址'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            SizedBox(height: 6),
            Text(
              L10n.t('直接打开任意网址（无需 SSH 隧道）'),
              style: TextStyle(fontSize: 12, color: AppColors.text.withOpacity(0.55)),
            ),
            SizedBox(height: 14),
            GlassTextField(
              controller: _url,
              label: L10n.t('网址'),
              icon: Icons.link,
              keyboard: TextInputType.url,
              hint: 'https://…',
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('取消'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('打开'),
                    icon: Icons.open_in_new,
                    primary: true,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
