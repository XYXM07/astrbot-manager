import '../l10n.dart';

/// 将启动时间格式化为可读的运行时长
String formatUptime(DateTime? startedAt) {
  if (startedAt == null) return L10n.t('未知');
  final d = DateTime.now().difference(startedAt);
  if (d.isNegative) return L10n.t('刚刚');
  if (d.inMinutes < 1) return L10n.t('{n} 秒', {'n': '${d.inSeconds}'});
  if (d.inHours < 1) return L10n.t('{n} 分钟', {'n': '${d.inMinutes}'});
  if (d.inDays < 1) return L10n.t('{n} 小时 {m} 分钟', {'n': '${d.inHours}', 'm': '${d.inMinutes % 60}'});
  return L10n.t('{n} 天 {h} 小时', {'n': '${d.inDays}', 'h': '${d.inHours % 24}'});
}
