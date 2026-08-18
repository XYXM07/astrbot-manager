/// APP 全局设置
class AppSettings {
  /// 毛玻璃背景模糊
  bool blurEnabled;

  /// 模糊强度（sigma 值）
  double blurSigma;

  /// 浅色模式（v1.13 起默认浅色）
  bool lightMode;

  /// 应用刷新率/帧率：30 / 60 / 120，0 表示无限制（跟随系统）
  int frameRate;

  /// 界面语言：zh（中文）/ en（English）
  String language;

  /// 状态自动刷新周期（秒），0 表示关闭
  int autoRefreshSeconds;

  /// 日志默认拉取行数
  int logLines;

  /// 日志字号
  double logFontSize;

  /// 自定义背景图片路径（空表示默认渐变背景）
  String backgroundImagePath;

  /// 界面顶部图标（1:1 图片，空表示使用默认图标）
  String logoImagePath;

  AppSettings({
    this.blurEnabled = false,
    this.blurSigma = 22,
    this.lightMode = true,
    this.frameRate = 120,
    this.language = 'zh',
    this.autoRefreshSeconds = 0,
    this.logLines = 200,
    this.logFontSize = 14.0,
    this.backgroundImagePath = '',
    this.logoImagePath = '',
  });

  AppSettings copyWith({
    bool? blurEnabled,
    double? blurSigma,
    bool? lightMode,
    int? frameRate,
    String? language,
    int? autoRefreshSeconds,
    int? logLines,
    double? logFontSize,
    String? backgroundImagePath,
    String? logoImagePath,
  }) {
    return AppSettings(
      blurEnabled: blurEnabled ?? this.blurEnabled,
      blurSigma: blurSigma ?? this.blurSigma,
      lightMode: lightMode ?? this.lightMode,
      frameRate: frameRate ?? this.frameRate,
      language: language ?? this.language,
      autoRefreshSeconds: autoRefreshSeconds ?? this.autoRefreshSeconds,
      logLines: logLines ?? this.logLines,
      logFontSize: logFontSize ?? this.logFontSize,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      logoImagePath: logoImagePath ?? this.logoImagePath,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    return AppSettings(
      blurEnabled: j['blurEnabled'] as bool? ?? false,
      blurSigma: (j['blurSigma'] as num?)?.toDouble() ?? 22,
      lightMode: j['lightMode'] as bool? ?? true,
      frameRate: j['frameRate'] as int? ?? 120,
      language: j['language'] as String? ?? 'zh',
      autoRefreshSeconds: j['autoRefreshSeconds'] as int? ?? 0,
      logLines: j['logLines'] as int? ?? 200,
      logFontSize: (j['logFontSize'] as num?)?.toDouble() ?? 14.0,
      backgroundImagePath: j['backgroundImagePath'] as String? ?? '',
      logoImagePath: j['logoImagePath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'blurEnabled': blurEnabled,
        'blurSigma': blurSigma,
        'lightMode': lightMode,
        'frameRate': frameRate,
        'language': language,
        'autoRefreshSeconds': autoRefreshSeconds,
        'logLines': logLines,
        'logFontSize': logFontSize,
        'backgroundImagePath': backgroundImagePath,
        'logoImagePath': logoImagePath,
      };
}
