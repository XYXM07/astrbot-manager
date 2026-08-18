import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models/config.dart';
import '../services/manager.dart';
import '../state/app_state.dart';
import '../state/shell_tabs.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/background.dart';
import '../widgets/glass.dart';
import '../widgets/service_editor.dart';
import '../widgets/service_icon.dart';
import 'connection_screen.dart';
import 'logs_screen.dart';

/// 首页：服务仪表盘
class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _autoTimer;
  int _autoSeconds = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshAll();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _syncAutoRefresh(int seconds) {
    if (seconds == _autoSeconds) return;
    _autoSeconds = seconds;
    _autoTimer?.cancel();
    _autoTimer = null;
    if (seconds > 0) {
      _autoTimer = Timer.periodic(Duration(seconds: seconds), (_) {
        final app = context.read<AppState>();
        if (mounted && app.connected && !app.refreshing) {
          app.refreshAll();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cfg = app.config;
    if (cfg == null) return SizedBox.shrink();
    _syncAutoRefresh(app.settings.autoRefreshSeconds);
    return GradientBackground(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => app.refreshAll(),
          color: AppColors.violet,
          backgroundColor: AppColors.light ? Colors.white : Color(0xFF232959),
          child: CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                sliver: SliverToBoxAdapter(child: _header(app, cfg)),
              ),
              if (app.connError != null &&
                  (app.connState == ConnState.error || app.connState == ConnState.disconnected))
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(child: _banner(app)),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final s = cfg.services[i];
                      return Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: _ServiceCard(service: s, app: app),
                      );
                    },
                    childCount: cfg.services.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 30),
                sliver: SliverToBoxAdapter(child: _addServiceCard()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppState app, ServerConfig cfg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(colors: [AppColors.violet, AppColors.cyan]),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: _headerLogo(app),
                    ),
                  ),
                  SizedBox(width: 11),
                  Text(
                    'astrbot助手',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ConnectionScreen(editMode: true)),
                ),
                child: _connChip(app, cfg),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _iconBtn(
              Icons.settings,
              () => ShellTabs.index.value = 2,
            ),
            SizedBox(width: 8),
            if (app.connected)
              _iconBtn(Icons.power_settings_new, () {
                app.disconnect();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.t('已断开连接'))),
                );
              }),
            SizedBox(width: 8),
            _iconBtn(
              Icons.refresh,
              app.refreshing ? null : () => app.refreshAll(),
              spinning: app.refreshing,
            ),
          ],
        ),
      ],
    );
  }

  /// 顶部界面图标：设置中自定义的图片优先，否则默认图标
  Widget _headerLogo(AppState app) {
    final p = app.settings.logoImagePath;
    if (p.isNotEmpty && File(p).existsSync()) {
      return Image.file(File(p), width: 40, height: 40, fit: BoxFit.cover);
    }
    return Image.asset('assets/icon.png', width: 40, height: 40, fit: BoxFit.cover);
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {bool spinning = false}) {
    return Material(
      color: AppColors.text.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: spinning ? null : onTap,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: spinning
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet),
                )
              : Icon(icon, size: 20, color: AppColors.text.withOpacity(0.85)),
        ),
      ),
    );
  }

  Widget _connChip(AppState app, ServerConfig cfg) {
    final color = switch (app.connState) {
      ConnState.connected => AppColors.green,
      ConnState.connecting => AppColors.amber,
      ConnState.error => AppColors.red,
      ConnState.disconnected => AppColors.gray,
    };
    final label = switch (app.connState) {
      ConnState.connected => L10n.t('已连接'),
      ConnState.connecting => L10n.t('连接中…'),
      ConnState.error => L10n.t('连接失败'),
      ConnState.disconnected => L10n.t('未连接'),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.text.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withOpacity(0.9), blurRadius: 7)],
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${cfg.username}@${cfg.host}:${cfg.port} · $label',
            style: TextStyle(fontSize: 12.5, color: AppColors.text.withOpacity(0.75)),
          ),
          SizedBox(width: 4),
          Icon(Icons.edit, size: 13, color: AppColors.text.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _banner(AppState app) {
    final isError = app.connState == ConnState.error;
    return GlassCard(
      tint: isError ? AppColors.red : AppColors.gray,
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            isError ? Icons.wifi_off : Icons.wifi,
            size: 20,
            color: isError ? AppColors.red : AppColors.gray,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              isError ? (app.connError ?? L10n.t('连接失败')) : L10n.t('尚未连接服务器'),
              style: TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
          FrostedButton(
            label: isError ? L10n.t('重试') : L10n.t('连接'),
            color: isError ? AppColors.red : AppColors.violet,
            onPressed: () => app.refreshAll(),
          ),
        ],
      ),
    );
  }

  Widget _addServiceCard() {
    return GlassCard(
      onTap: () => showServiceEditor(context),
      padding: EdgeInsets.all(18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle, size: 20, color: AppColors.text.withOpacity(0.6)),
          SizedBox(width: 8),
          Text(
            L10n.t('添加服务'),
            style: TextStyle(fontSize: 14, color: AppColors.text.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

/// 单个服务卡片
class _ServiceCard extends StatelessWidget {
  final ServiceConfig service;
  final AppState app;
  _ServiceCard({required this.service, required this.app});

  Future<void> _confirmRestart(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => _ConfirmRestartDialog(service: service),
    );
    if (ok != true) return;
    final success = await app.restart(service);
    if (!context.mounted) return;
    final st = app.statusOf(service);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? L10n.t('{name} 重启命令已执行', {'name': service.name})
              : L10n.t('重启失败：{msg}', {'msg': st.message ?? L10n.t('未知错误')}),
        ),
      ),
    );
  }

  Widget _statusLine(ServiceStatus st) {
    if (st.isError) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error, size: 15, color: AppColors.red),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              L10n.t('获取状态失败：{msg}', {'msg': '${st.message}'}),
              style: TextStyle(fontSize: 12.5, color: AppColors.red),
            ),
          ),
        ],
      );
    }
    switch (st.state) {
      case 'running':
        return Text(
          L10n.t('已运行 {info}', {'info': '${formatUptime(st.startedAt)}${st.image != null ? ' · ${st.image}' : ''}'}),
          style: TextStyle(fontSize: 12.5, color: AppColors.text.withOpacity(0.8)),
        );
      case 'restarting':
        return Text(
          L10n.t('正在重启，请稍候…'),
          style: TextStyle(fontSize: 12.5, color: AppColors.amber),
        );
      case 'exited':
        return Text(
          L10n.t('已停止（退出码 {code}）', {'code': '${st.exitCode ?? '-'}'}),
          style: TextStyle(fontSize: 12.5, color: AppColors.red),
        );
      case 'missing':
        return Text(
          L10n.t('未找到该{kind}，请检查配置', {'kind': service.kind.shortLabel}),
          style: TextStyle(fontSize: 12.5, color: AppColors.gray.withOpacity(0.9)),
        );
      default:
        return Text(
          L10n.t('状态：{state}', {'state': st.state}),
          style: TextStyle(fontSize: 12.5, color: AppColors.gray.withOpacity(0.9)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = app.statusOf(service);
    final isBusy = app.busy.contains(service.id);
    return GlassCard(
      padding: EdgeInsets.all(17),
      tint: service.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ServiceIcon(
                imageAsset: service.imageAsset,
                imagePath: service.imagePath,
                color: service.color,
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${service.kind.shortLabel} · ${service.target}',
                      style: TextStyle(fontSize: 12, color: AppColors.text.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              StatusPill(state: st.state),
              SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.more_horiz, size: 20, color: AppColors.text.withOpacity(0.6)),
                onPressed: () => _showActions(context),
              ),
            ],
          ),
          SizedBox(height: 13),
          _statusLine(st),
          SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FrostedButton(
                  label: isBusy ? L10n.t('重启中…') : L10n.t('重启'),
                  icon: Icons.restart_alt,
                  primary: true,
                  color: AppColors.violet,
                  loading: isBusy,
                  onPressed: isBusy ? null : () => _confirmRestart(context),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: FrostedButton(
                  label: L10n.t('日志'),
                  icon: Icons.terminal,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LogsScreen(service: service)),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: FrostedButton(
                  label: 'WebUI',
                  icon: Icons.language,
                  onPressed: () {
                    context.read<AppState>().openWebuiSession(service);
                    ShellTabs.index.value = 1;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FrostedSheet(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ListTile(
              leading: Icon(Icons.refresh, color: AppColors.text),
              title: Text(L10n.t('刷新状态'), style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.of(ctx).pop();
                app.refreshOne(service);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit, color: AppColors.text),
              title: Text(L10n.t('编辑服务'), style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.of(ctx).pop();
                showServiceEditor(context, existing: service);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.red),
              title: Text(L10n.t('删除服务'), style: TextStyle(color: AppColors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                app.removeService(service.id);
              },
            ),
            SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }
}

class _ConfirmRestartDialog extends StatelessWidget {
  final ServiceConfig service;
  _ConfirmRestartDialog({required this.service});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 36),
      child: GlassCard(
        tint: AppColors.violet,
        backdropSigma: 36,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.amber.withOpacity(0.16),
                border: Border.all(color: AppColors.amber.withOpacity(0.4)),
              ),
              child: Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 28),
            ),
            SizedBox(height: 14),
            Text(
              L10n.t('确认重启 {name}？', {'name': service.name}),
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              L10n.t('将远程执行重启命令，服务会短暂离线。'),
              style: TextStyle(fontSize: 13, color: AppColors.text.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('取消'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('确认重启'),
                    icon: Icons.restart_alt,
                    primary: true,
                    color: AppColors.amber,
                    onPressed: () => Navigator.of(context).pop(true),
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
