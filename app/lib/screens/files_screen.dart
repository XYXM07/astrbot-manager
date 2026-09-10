import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../services/sftp_manager.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/background.dart';
import '../widgets/glass.dart';

/// 远程文件管理页（SFTP）
class FilesScreen extends StatefulWidget {
  FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  static const _maxMemoryBytes = 64 * 1024 * 1024;

  SftpManager? _mgr;
  String _dir = '/';
  List<RemoteFile> _entries = const [];
  bool _loading = true;
  String? _error;
  bool _showHidden = false;
  String _sort = 'name';

  bool _multi = false;
  final Set<String> _selected = {};

  List<String>? _clip;
  String? _clipMode;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final app = context.read<AppState>();
    _mgr = SftpManager(app.ssh);
    // 以登录用户的家目录为起点
    try {
      final r = await app.ssh.run(r'echo $HOME');
      if (r.ok && r.stdout.trim().isNotEmpty) {
        _dir = r.stdout.trim();
      }
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    final mgr = _mgr;
    if (mgr == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await mgr.list(_dir);
      if (!mounted) return;
      setState(() {
        _entries = list;
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

  List<RemoteFile> get _visible {
    final list = _showHidden
        ? _entries
        : _entries.where((e) => !e.name.startsWith('.')).toList();
    list.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      switch (_sort) {
        case 'size':
          return (b.size ?? 0).compareTo(a.size ?? 0);
        case 'time':
          return (b.mtime ?? 0).compareTo(a.mtime ?? 0);
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return list;
  }

  String _parent(String dir) {
    if (dir == '/' || dir.isEmpty) return '/';
    final i = dir.lastIndexOf('/');
    if (i <= 0) return '/';
    return dir.substring(0, i);
  }

  String _base(String path) => path.split('/').last;

  void _go(String dir) {
    _dir = dir;
    _selected.clear();
    _load();
  }

  // ── 对话框 / 操作 ──────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _promptText(String title, String initial, String hint) async {
    final c = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassCard(
          tint: AppColors.violet,
          backdropSigma: 36,
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
              SizedBox(height: 14),
              GlassTextField(controller: c, label: hint, icon: Icons.edit),
              SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('取消'),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('保存'),
                    icon: Icons.check,
                    primary: true,
                    onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    c.dispose();
    return (r == null || r.isEmpty) ? null : r;
  }

  Future<void> _newFolder() async {
    final name = await _promptText(L10n.t('新建文件夹'), '', L10n.t('文件夹名称'));
    if (name == null) return;
    try {
      await _mgr!.mkdir(_mgr!.join(_dir, name));
      _snack(L10n.t('新建成功'));
      _load();
    } catch (e) {
      _snack(L10n.t('操作失败：{err}', {'err': '$e'}));
    }
  }

  Future<void> _rename(RemoteFile f) async {
    final name = await _promptText(L10n.t('重命名'), f.name, L10n.t('新名称'));
    if (name == null || name == f.name) return;
    try {
      await _mgr!.rename(f.path, _mgr!.join(_dir, name));
      _snack(L10n.t('重命名成功'));
      _load();
    } catch (e) {
      _snack(L10n.t('操作失败：{err}', {'err': '$e'}));
    }
  }

  Future<void> _deletePaths(List<String> paths) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassCard(
          tint: AppColors.red,
          backdropSigma: 36,
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 34),
              SizedBox(height: 12),
              Text(
                paths.length == 1
                    ? L10n.t('确认删除 {name}？', {'name': _base(paths.first)})
                    : L10n.t('确认删除选中的 {n} 项？', {'n': '${paths.length}'}),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                L10n.t('此操作不可恢复。'),
                style: TextStyle(fontSize: 12.5, color: AppColors.text.withOpacity(0.6)),
              ),
              SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('取消'),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('删除'),
                    icon: Icons.delete,
                    primary: true,
                    color: AppColors.red,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    var failed = 0;
    for (final p in paths) {
      try {
        await _mgr!.delete(p);
      } catch (_) {
        failed++;
      }
    }
    if (failed == 0) {
      _snack(L10n.t('删除成功'));
    } else {
      _snack(L10n.t('删除失败：{n} 项未能删除（可能目录非空或无权限）', {'n': '$failed'}));
    }
    setState(() {
      _selected.clear();
      _multi = false;
    });
    _load();
  }

  Future<void> _upload() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null || res.files.isEmpty) return;
    for (final f in res.files) {
      final path = f.path;
      if (path == null || f.name.isEmpty) continue;
      if (f.size > _maxMemoryBytes) {
        _snack(L10n.t('文件过大，无法上传（超过 64MB）：{name}', {'name': f.name}));
        continue;
      }
      setState(() => _loading = true);
      try {
        final bytes = await File(path).readAsBytes();
        await _mgr!.writeBytes(_mgr!.join(_dir, f.name), bytes);
      } catch (e) {
        _snack(L10n.t('上传失败：{err}', {'err': '$e'}));
      }
    }
    setState(() => _loading = false);
    _snack(L10n.t('上传完成（{n} 个文件）', {'n': '${res.files.length}'}));
    _load();
  }

  Future<void> _downloadAndShare(RemoteFile f) async {
    if (f.size != null && f.size! > _maxMemoryBytes) {
      _snack(L10n.t('文件过大，无法下载（超过 64MB）'));
      return;
    }
    try {
      final bytes = await _mgr!.readBytes(f.path);
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/downloads')..createSync(recursive: true);
      final file = File('${dir.path}/${f.name}');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      _snack(L10n.t('下载失败：{err}', {'err': '$e'}));
    }
  }

  Future<void> _preview(RemoteFile f) async {
    try {
      final bytes = await _mgr!.readBytes(f.path, length: 64 * 1024);
      // 按 UTF-8 解码（否则中文等多字节字符会乱码）
      final raw = utf8.decode(bytes, allowMalformed: true);
      final broken = '\uFFFD'.allMatches(raw).length;
      final text = broken > 3
          ? '${L10n.t('（该文件可能不是 UTF-8 编码，部分字符可能显示异常）')}\n\n$raw'
          : raw;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 24),
          child: GlassCard(
            tint: AppColors.violet,
            backdropSigma: 36,
            padding: EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${L10n.t('文本预览')} · ${f.name}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.terminalBg,
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          text,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.terminalText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: FrostedButton(
                        label: L10n.t('下载'),
                        icon: Icons.download,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _downloadAndShare(f);
                        },
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: FrostedButton(
                        label: L10n.t('取消'),
                        icon: Icons.close,
                        primary: true,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      _snack(L10n.t('读取失败：{err}', {'err': '$e'}));
    }
  }

  Future<void> _tapFile(RemoteFile f) async {
    final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
    const textExts = {
      'txt', 'log', 'json', 'yaml', 'yml', 'conf', 'ini', 'md', 'sh', 'py',
      'js', 'ts', 'css', 'html', 'xml', 'env', 'cfg', 'csv', 'toml',
    };
    if (textExts.contains(ext) && (f.size ?? 0) <= 512 * 1024) {
      await _preview(f);
      return;
    }
    // 非文本：操作菜单
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FrostedSheet(
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(Icons.download, color: AppColors.text),
              title: Text(L10n.t('下载并分享'), style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.of(ctx).pop('share');
              },
            ),
            ListTile(
              leading: Icon(Icons.drive_file_rename_outline, color: AppColors.text),
              title: Text(L10n.t('重命名'), style: TextStyle(color: AppColors.text)),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.red),
              title: Text(L10n.t('删除'), style: TextStyle(color: AppColors.red)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            SizedBox(height: 8),
          ]),
        ),
      ),
    );
    switch (act) {
      case 'share':
        await _downloadAndShare(f);
      case 'rename':
        await _rename(f);
      case 'delete':
        await _deletePaths([f.path]);
    }
  }

  Future<void> _paste() async {
    final clip = _clip;
    final mode = _clipMode;
    if (clip == null || mode == null) return;
    var failed = 0;
    for (final src in clip) {
      final dst = _mgr!.join(_dir, _base(src));
      if (dst == src) continue;
      try {
        if (mode == 'move') {
          await _mgr!.rename(src, dst);
        } else {
          await _mgr!.copy(src, dst);
        }
      } catch (_) {
        failed++;
      }
    }
    setState(() {
      _clip = null;
      _clipMode = null;
    });
    if (failed == 0) {
      _snack(L10n.t('粘贴完成'));
    } else {
      _snack(L10n.t('粘贴完成，{n} 项失败', {'n': '$failed'}));
    }
    _load();
  }

  // ── UI ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              if (_clip != null)
                Container(
                  width: double.infinity,
                  color: AppColors.violet.withOpacity(0.16),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        L10n.t('已复制 {n} 项，点击粘贴到当前目录', {'n': '${_clip!.length}'}),
                        style: TextStyle(fontSize: 12, color: AppColors.text),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _clip = null;
                          _clipMode = null;
                        });
                      },
                      child: Icon(Icons.close, size: 16, color: AppColors.text.withOpacity(0.7)),
                    ),
                  ]),
                ),
              // 路径栏
              Padding(
                padding: EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_upward, size: 20),
                    tooltip: L10n.t('上级目录'),
                    onPressed: _dir == '/' ? null : () => _go(_parent(_dir)),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final seg in _pathSegments()) ...[
                          GestureDetector(
                            onTap: () => _go(seg.path),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: seg.path == _dir
                                    ? AppColors.violet.withOpacity(0.18)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                seg.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: seg.path == _dir ? FontWeight.w700 : FontWeight.w400,
                                  color: AppColors.text.withOpacity(seg.path == _dir ? 1 : 0.65),
                                ),
                              ),
                            ),
                          ),
                          if (seg.path != _dir)
                            Text('/', style: TextStyle(fontSize: 12, color: AppColors.text.withOpacity(0.4))),
                        ],
                      ]),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.upload_file, size: 21),
                    tooltip: L10n.t('上传文件'),
                    onPressed: _upload,
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20),
                    onPressed: _loading ? null : _load,
                  ),
                ]),
              ),
              // 工具栏
              Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 4),
                child: Row(children: [
                  _toolChip(Icons.create_new_folder, L10n.t('新建文件夹'), _newFolder),
                  SizedBox(width: 8),
                  _toolChip(Icons.drive_file_move, L10n.t('粘贴'), _clip == null ? null : _paste),
                  Spacer(),
                  IconButton(
                    icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off, size: 19),
                    tooltip: L10n.t('显示隐藏文件'),
                    onPressed: () => setState(() => _showHidden = !_showHidden),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.sort, size: 20),
                    tooltip: L10n.t('排序'),
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'name', child: Text(L10n.t('按名称'))),
                      PopupMenuItem(value: 'size', child: Text(L10n.t('按大小'))),
                      PopupMenuItem(value: 'time', child: Text(L10n.t('按时间'))),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.checklist, size: 20),
                    tooltip: L10n.t('多选'),
                    onPressed: () => setState(() {
                      _multi = !_multi;
                      _selected.clear();
                    }),
                  ),
                ]),
              ),
              if (_loading)
                LinearProgressIndicator(minHeight: 2, color: AppColors.violet, backgroundColor: Colors.transparent),
              Expanded(
                child: _error != null
                    ? Center(
                        child: GlassCard(
                          tint: AppColors.red,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.error, color: AppColors.red, size: 30),
                            SizedBox(height: 10),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18),
                              child: Text(_error!, style: TextStyle(fontSize: 12.5, color: AppColors.text), textAlign: TextAlign.center),
                            ),
                            SizedBox(height: 14),
                            FrostedButton(label: L10n.t('重试'), icon: Icons.refresh, onPressed: _load),
                          ]),
                        ),
                      )
                    : visible.isEmpty
                        ? Center(
                            child: Text(
                              L10n.t('空目录'),
                              style: TextStyle(fontSize: 13, color: AppColors.text.withOpacity(0.5)),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.violet,
                            child: ListView.builder(
                              physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              itemCount: visible.length,
                              itemBuilder: (context, i) {
                                final f = visible[i];
                                final selected = _selected.contains(f.path);
                                return _tile(f, selected);
                              },
                            ),
                          ),
              ),
              if (_multi)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                  decoration: BoxDecoration(
                    color: AppColors.panelStrong,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        L10n.t('已选中 {n} 项', {'n': '${_selected.length}'}),
                        style: TextStyle(fontSize: 12.5, color: AppColors.text),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_selected.length == visible.length) {
                          setState(() => _selected.clear());
                        } else {
                          setState(() => _selected.addAll(visible.map((e) => e.path)));
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text(L10n.t('全选'), style: TextStyle(fontSize: 12.5, color: AppColors.violet)),
                      ),
                    ),
                    _miniBtn(Icons.content_copy, L10n.t('复制'), () {
                      if (_selected.isEmpty) return;
                      setState(() {
                        _clip = _selected.toList();
                        _clipMode = 'copy';
                        _multi = false;
                        _selected.clear();
                      });
                    }),
                    _miniBtn(Icons.drive_file_move, L10n.t('移动'), () {
                      if (_selected.isEmpty) return;
                      setState(() {
                        _clip = _selected.toList();
                        _clipMode = 'move';
                        _multi = false;
                        _selected.clear();
                      });
                    }),
                    _miniBtn(Icons.delete, L10n.t('删除'), () {
                      if (_selected.isNotEmpty) _deletePaths(_selected.toList());
                    }, danger: true),
                    _miniBtn(Icons.close, L10n.t('取消'), () {
                      setState(() {
                        _multi = false;
                        _selected.clear();
                      });
                    }),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolChip(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.text.withOpacity(onTap == null ? 0.04 : 0.08),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.text.withOpacity(onTap == null ? 0.3 : 0.8)),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.text.withOpacity(onTap == null ? 0.3 : 0.8),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _miniBtn(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    final c = danger ? AppColors.red : AppColors.text;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: c),
          SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: c)),
        ]),
      ),
    );
  }

  Widget _tile(RemoteFile f, bool selected) {
    final color = f.isDir
        ? AppColors.violet
        : _fileColor(f.name);
    return ListTile(
      dense: true,
      leading: Icon(
        f.isDir ? Icons.folder : Icons.insert_drive_file,
        color: color,
        size: 22,
      ),
      title: Text(
        f.name,
        style: TextStyle(fontSize: 13.5, color: AppColors.text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        f.isDir ? L10n.t('文件夹') : _fmtSize(f.size),
        style: TextStyle(fontSize: 11, color: AppColors.text.withOpacity(0.5)),
      ),
      trailing: _multi
          ? Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColors.violet : AppColors.text.withOpacity(0.35),
              size: 21,
            )
          : (f.isDir
              ? null
              : Text(
                  _fmtTime(f.mtime),
                  style: TextStyle(fontSize: 10.5, color: AppColors.text.withOpacity(0.4)),
                )),
      onTap: () {
        if (_multi) {
          setState(() {
            if (selected) {
              _selected.remove(f.path);
            } else {
              _selected.add(f.path);
            }
          });
          return;
        }
        if (f.isDir) {
          _go(f.path);
        } else {
          _tapFile(f);
        }
      },
      onLongPress: () {
        setState(() {
          _multi = true;
          _selected.add(f.path);
        });
      },
    );
  }

  Color _fileColor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'log':
        return AppColors.amber;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'toml':
        return AppColors.cyan;
      case 'sh':
      case 'py':
      case 'js':
      case 'ts':
        return AppColors.green;
      case 'zip':
      case 'gz':
      case 'tar':
        return AppColors.pink;
      default:
        return AppColors.gray;
    }
  }

  List<({String name, String path})> _pathSegments() {
    final parts = _dir.split('/').where((s) => s.isNotEmpty).toList();
    final out = <({String name, String path})>[];
    var acc = '';
    out.add((name: '/', path: '/'));
    for (final p in parts) {
      acc = acc.isEmpty ? '/$p' : '$acc/$p';
      out.add((name: p, path: acc));
    }
    return out;
  }

  String _fmtSize(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _fmtTime(int? sec) {
    if (sec == null) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
