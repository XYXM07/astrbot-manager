import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models/config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/background.dart';
import '../widgets/glass.dart';

/// 日志查看页：终端风格毛玻璃面板
class LogsScreen extends StatefulWidget {
  final ServiceConfig service;
  LogsScreen({super.key, required this.service});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ScrollController _scroll = ScrollController();
  String _logs = '';
  bool _loading = false;
  bool _auto = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_loading) return;
    final app = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final text =
          await app.fetchLogs(widget.service, lines: app.settings.logLines);
      if (!mounted) return;
      setState(() => _logs = text.isEmpty ? L10n.t('（暂无日志）') : text);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _logs = L10n.t('获取日志失败：{err}', {'err': '$e'}));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setAuto(bool v) {
    setState(() => _auto = v);
    _timer?.cancel();
    if (v) {
      _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetch());
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _logs));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.t('日志已复制到剪贴板'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(L10n.t('{name} · 日志', {'name': service.name})),
          actions: [
            IconButton(
              icon: Icon(Icons.copy, size: 20),
              onPressed: _logs.isEmpty ? null : _copy,
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: 20),
              onPressed: _loading ? null : _fetch,
            ),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Text(
                    L10n.t('自动'),
                    style: TextStyle(fontSize: 12, color: AppColors.text.withOpacity(0.6)),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: _auto,
                      activeTrackColor: AppColors.violet.withOpacity(0.6),
                      activeColor: AppColors.violet,
                      onChanged: _setAuto,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    borderless: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Container(
                            color: AppColors.terminalBg,
                            child: SingleChildScrollView(
                              controller: _scroll,
                              padding: EdgeInsets.all(14),
                              // 可长按选词/选段（像记事本一样），带复制菜单
                              child: SelectableText(
                                _logs,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: context
                                      .watch<AppState>()
                                      .settings
                                      .logFontSize,
                                  height: 1.55,
                                  color: AppColors.terminalText,
                                ),
                              ),
                            ),
                          ),
                          if (_loading && _logs.isEmpty)
                            Center(
                              child: CircularProgressIndicator(color: AppColors.violet),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FrostedButton(
                        label: _loading ? L10n.t('拉取中…') : L10n.t('刷新日志'),
                        icon: Icons.refresh,
                        loading: _loading,
                        primary: true,
                        onPressed: _fetch,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: FrostedButton(
                        label: L10n.t('滚动到底部'),
                        icon: Icons.vertical_align_bottom,
                        onPressed: () {
                          if (_scroll.hasClients) {
                            _scroll.animateTo(
                              _scroll.position.maxScrollExtent,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
