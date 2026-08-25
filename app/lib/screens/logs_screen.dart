import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models/config.dart';
import '../services/ai_analyze.dart';
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

  /// 最近一次文本选区（用于"选中分析"）
  TextSelection? _sel;

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

  /// AI 一键分析：有选中内容则分析选中部分，否则分析全部日志
  Future<void> _analyze() async {
    final app = context.read<AppState>();
    final s = app.settings;
    if (s.apiBaseUrl.trim().isEmpty ||
        s.apiKey.trim().isEmpty ||
        s.apiModel.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('请先在设置中配置 AI 分析 API'))),
      );
      return;
    }
    final sel = _sel;
    final useSel = sel != null && sel.isValid && !sel.isCollapsed;
    var content = (useSel ? sel.textInside(_logs) : _logs).trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('没有可分析的内容'))),
      );
      return;
    }
    if (content.length > 12000) content = '${content.substring(0, 12000)}\n…';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FrostedSheet(
        child: _AiResultSheet(
          content: content,
          baseUrl: s.apiBaseUrl.trim(),
          apiKey: s.apiKey.trim(),
          model: s.apiModel.trim(),
          useSelection: useSel,
        ),
      ),
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
                              // 可长按选词/选段（像记事本一样），带复制菜单；
                              // 记录选区供"AI 选中分析"使用
                              child: SelectableText(
                                _logs,
                                onSelectionChanged: (s, _) => _sel = s,
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
                    SizedBox(width: 10),
                    FrostedButton(
                      label: L10n.t('AI 分析'),
                      icon: Icons.auto_awesome,
                      color: AppColors.violet,
                      onPressed: _logs.isEmpty ? null : _analyze,
                    ),
                    SizedBox(width: 10),
                    Tooltip(
                      message: L10n.t('滚动到底部'),
                      child: FrostedButton(
                        label: '',
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

/// AI 分析结果面板：打开后自动调用接口，展示加载/结果/错误状态
class _AiResultSheet extends StatefulWidget {
  final String content;
  final String baseUrl;
  final String apiKey;
  final String model;
  final bool useSelection;

  const _AiResultSheet({
    required this.content,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.useSelection,
  });

  @override
  State<_AiResultSheet> createState() => _AiResultSheetState();
}

class _AiResultSheetState extends State<_AiResultSheet> {
  bool _loading = true;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AiAnalyzeService.analyze(
        baseUrl: widget.baseUrl,
        apiKey: widget.apiKey,
        model: widget.model,
        content: widget.content,
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: AppColors.violet),
                SizedBox(width: 8),
                Text(
                  L10n.t('AI 分析结果'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.violet.withOpacity(0.14),
                  ),
                  child: Text(
                    widget.useSelection
                        ? L10n.t('分析选中内容')
                        : L10n.t('分析全部日志'),
                    style: TextStyle(fontSize: 11.5, color: AppColors.violet),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.violet),
                      SizedBox(height: 14),
                      Text(
                        L10n.t('正在分析…'),
                        style: TextStyle(fontSize: 13, color: AppColors.text.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.red.withOpacity(0.12),
                    ),
                    child: Text(
                      L10n.t('分析失败：{err}', {'err': _error!}),
                      style: TextStyle(fontSize: 12.5, color: AppColors.red),
                    ),
                  ),
                  SizedBox(height: 12),
                  FrostedButton(
                    label: L10n.t('重试'),
                    icon: Icons.refresh,
                    color: AppColors.red,
                    onPressed: _run,
                  ),
                ],
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 380),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.terminalBg,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _result ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.terminalText,
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: 14),
            Row(
              children: [
                if (_result != null) ...[
                  Expanded(
                    child: FrostedButton(
                      label: L10n.t('复制结果'),
                      icon: Icons.copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _result!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(L10n.t('已复制到剪贴板'))),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                ],
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('取消'),
                    icon: Icons.close,
                    primary: true,
                    onPressed: () => Navigator.of(context).pop(),
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
