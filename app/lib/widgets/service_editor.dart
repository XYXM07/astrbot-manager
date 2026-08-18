import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models/config.dart';
import '../services/manager.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/image_utils.dart';
import 'glass.dart';
import 'service_icon.dart';

/// 打开服务编辑对话框（existing 为 null 时表示新增）
Future<void> showServiceEditor(BuildContext context, {ServiceConfig? existing}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _ServiceEditorDialog(existing: existing),
  );
}

class _ServiceEditorDialog extends StatefulWidget {
  final ServiceConfig? existing;
  _ServiceEditorDialog({this.existing});

  @override
  State<_ServiceEditorDialog> createState() => _ServiceEditorDialogState();
}

class _ServiceEditorDialogState extends State<_ServiceEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _composeFile;
  late final TextEditingController _webuiPort;
  late final TextEditingController _webuiPath;
  late ServiceKind _kind;
  bool _detecting = false;
  String? _error;
  String? _stickerPath;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _target = TextEditingController(text: e?.target ?? '');
    _composeFile = TextEditingController(text: e?.composeFile ?? '');
    _webuiPort = TextEditingController(text: (e?.webuiPort ?? 6185).toString());
    _webuiPath = TextEditingController(text: e?.webuiPath ?? '');
    _kind = e?.kind ?? ServiceKind.container;
    _stickerPath = e?.imagePath;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _composeFile.dispose();
    _webuiPort.dispose();
    _webuiPath.dispose();
    super.dispose();
  }

  /// 选择 1:1 比例的贴图
  Future<void> _pickSticker() async {
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
          setState(() => _error = L10n.t('请选择 1:1 比例的图片'));
        }
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final dest =
          '${dir.path}/sticker_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(picked.path).copy(dest);
      if (mounted) {
        setState(() {
          _stickerPath = dest;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = L10n.t('选择图片失败：{err}', {'err': '$e'}));
    }
  }

  Color get _accent {
    switch (_kind) {
      case ServiceKind.container:
        return AppColors.cyan;
      case ServiceKind.compose:
        return AppColors.violet;
      case ServiceKind.systemd:
        return AppColors.green;
    }
  }

  /// 从服务器自动检测容器列表
  Future<void> _detect() async {
    final app = context.read<AppState>();
    setState(() {
      _detecting = true;
      _error = null;
    });
    try {
      final list = await app.detectContainers();
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() => _error = L10n.t('服务器上没有检测到任何容器'));
        return;
      }
      final picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => FrostedSheet(child: _ContainerPicker(list: list)),
      );
      if (picked != null && mounted) {
        _target.text = picked;
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  void _save() {
    if (_name.text.trim().isEmpty || _target.text.trim().isEmpty) {
      setState(() => _error = L10n.t('请填写显示名与服务名'));
      return;
    }
    final app = context.read<AppState>();
    final cfg = ServiceConfig(
      id: widget.existing?.id ??
          'svc_${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(),
      target: _target.text.trim(),
      kind: _kind,
      composeFile: _composeFile.text.trim(),
      colorValue: widget.existing?.colorValue ?? _accent.toARGB32(),
      webuiPort: int.tryParse(_webuiPort.text.trim()) ?? 6185,
      webuiPath: _webuiPath.text.trim(),
      imageAsset: widget.existing?.imageAsset,
      imagePath: _stickerPath,
    );
    app.saveService(cfg);
    Navigator.of(context).pop();
  }

  Widget _kindChip(ServiceKind k) {
    final selected = k == _kind;
    final c = selected ? _accent : AppColors.text;
    return GestureDetector(
      onTap: () => setState(() => _kind = k),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? _accent.withOpacity(0.2) : AppColors.text.withOpacity(0.06),
        ),
        child: Text(
          k.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c : AppColors.text.withOpacity(0.65),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        tint: _accent,
        backdropSigma: 36,
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? L10n.t('添加服务') : L10n.t('编辑服务'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 贴图：点击更换（仅接受 1:1 比例）
                  GestureDetector(
                    onTap: _pickSticker,
                    child: ServiceIcon(
                      imageAsset: widget.existing?.imageAsset,
                      imagePath: _stickerPath,
                      color: _accent,
                      size: 56,
                      radius: 16,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GlassTextField(
                      controller: _name,
                      label: L10n.t('显示名'),
                      icon: Icons.label,
                      hint: L10n.t('例如 AstrBot'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              Text(
                L10n.t('管理方式'),
                style: TextStyle(fontSize: 12.5, color: AppColors.text.withOpacity(0.60)),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  for (final k in ServiceKind.values) ...[
                    Expanded(child: _kindChip(k)),
                    if (k != ServiceKind.values.last) SizedBox(width: 8),
                  ],
                ],
              ),
              SizedBox(height: 14),
              GlassTextField(
                controller: _target,
                label: _kind == ServiceKind.container
                    ? L10n.t('容器名')
                    : _kind == ServiceKind.compose
                        ? L10n.t('Compose 服务名')
                        : L10n.t('systemd 服务名'),
                icon: Icons.dns,
                hint: _kind == ServiceKind.container
                    ? L10n.t('例如 astrbot（可用下方“检测”自动获取）')
                    : L10n.t('例如 astrbot'),
                suffix: _kind == ServiceKind.container
                    ? TextButton(
                        onPressed: _detecting ? null : _detect,
                        child: _detecting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(L10n.t('检测'), style: TextStyle(fontSize: 13)),
                      )
                    : null,
              ),
              if (_kind == ServiceKind.compose) ...[
                SizedBox(height: 14),
                GlassTextField(
                  controller: _composeFile,
                  label: L10n.t('compose 文件路径（可留空）'),
                  icon: Icons.description,
                  hint: L10n.t('例如 /opt/astrbot/docker-compose.yml'),
                ),
              ],
              SizedBox(height: 14),
              GlassTextField(
                controller: _webuiPort,
                label: L10n.t('WebUI 端口（APP 内通过 SSH 隧道打开）'),
                icon: Icons.language,
                keyboard: TextInputType.number,
                hint: L10n.t('AstrBot 默认 6185，NapCat 默认 6099'),
              ),
              SizedBox(height: 14),
              GlassTextField(
                controller: _webuiPath,
                label: L10n.t('WebUI 访问路径（可留空）'),
                icon: Icons.link,
                hint: L10n.t('例如 /webui?token=xxx（NapCat 开启 token 时填写）'),
              ),
              if (_error != null) ...[
                SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, color: AppColors.red),
                ),
              ],
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
                      label: L10n.t('保存'),
                      icon: Icons.check,
                      primary: true,
                      color: _accent,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContainerPicker extends StatelessWidget {
  final List<ContainerInfo> list;
  _ContainerPicker({required this.list});

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
              L10n.t('选择容器'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final c = list[i];
                final color = c.state == 'running' ? AppColors.green : AppColors.gray;
                return ListTile(
                  leading: Icon(Icons.inventory_2, color: color),
                  title: Text(
                    c.name,
                    style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(c.status, style: TextStyle(color: AppColors.text.withOpacity(0.54), fontSize: 12)),
                  trailing: StatusPill(state: c.state),
                  onTap: () => Navigator.of(context).pop(c.name),
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
