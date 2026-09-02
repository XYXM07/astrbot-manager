import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../services/update_check.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../version.dart';
import 'glass.dart';

/// 执行更新检查。
/// [auto]=true 为启动时后台检查：失败静默；有新版本才弹窗。
/// [auto]=false 为手动检查：已最新/失败都会提示。
Future<void> performUpdateCheck(BuildContext context, {bool auto = false}) async {
  if (!context.mounted) return;
  final app = context.read<AppState>();
  if (auto && !app.settings.autoCheckUpdate) return;

  UpdateInfo? info;
  Object? err;
  try {
    info = await UpdateService.check();
  } catch (e) {
    err = e;
  }
  if (!context.mounted) return;
  if (err != null) {
    if (!auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('检查更新失败：{err}', {'err': '$err'}))),
      );
    }
    return;
  }
  if (info == null) {
    if (!auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('已是最新版本'))),
      );
    }
    return;
  }
  final upd = info;
  await showDialog<void>(
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
            Row(
              children: [
                Icon(Icons.system_update_alt, size: 22, color: AppColors.violet),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L10n.t('发现新版本 v{v}', {'v': upd.version}),
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              L10n.t('当前版本 v{v}', {'v': appVersion}),
              style: TextStyle(fontSize: 12, color: AppColors.text.withOpacity(0.55)),
            ),
            if (upd.notes != null) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: 240),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.text.withOpacity(0.06),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    upd.notes!,
                    style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.text.withOpacity(0.85)),
                  ),
                ),
              ),
            ],
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('稍后'),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: FrostedButton(
                    label: L10n.t('下载更新'),
                    icon: Icons.download,
                    primary: true,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      final url = upd.apkUrl ??
                          'https://github.com/XYXM07/astrbot-manager/releases/latest';
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
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
