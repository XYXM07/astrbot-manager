/// 轻量国际化：以中文原文为 key，英文模式下查表替换。
/// 用法：L10n.t('连接并保存')；带参数：L10n.t('连接失败：{err}', {'err': e})。
class L10n {
  /// 当前语言（由入口在构建前根据设置同步）
  static String lang = 'zh';

  static String t(String zh, [Map<String, String>? args]) {
    var s = lang == 'en' ? (_en[zh] ?? zh) : zh;
    if (args != null) {
      for (final e in args.entries) {
        s = s.replaceAll('{${e.key}}', e.value);
      }
    }
    return s;
  }

  static const Map<String, String> _en = {
    // ── 底部导航 ──
    '仪表盘': 'Dashboard',
    '设置': 'Settings',
    // ── 连接页 ──
    '请输入服务器地址': 'Please enter the server address',
    '连接失败：{err}': 'Connection failed: {err}',
    '未知错误': 'unknown error',
    '更新服务器连接信息': 'Update server connection info',
    '远程管理你的 AstrBot 与 NapCat': 'Manage your AstrBot and NapCat remotely',
    '服务器地址（例如 47.100.12.34）': 'Server address (e.g. 47.100.12.34)',
    '端口': 'Port',
    '用户名（root）': 'Username (root)',
    '阿里云登录': 'Alibaba Cloud',
    '私钥登录': 'Private key',
    '密码': 'Password',
    '私钥 PEM 文本': 'Private key PEM text',
    '私钥口令（无则留空）': 'Key passphrase (leave empty if none)',
    '命令前加 sudo（非 root 用户请开启）':
        'Prepend sudo to commands (enable for non-root users)',
    '连接中…': 'Connecting…',
    '保存并重新连接': 'Save & reconnect',
    '连接并保存': 'Connect & save',
    '连接信息仅加密保存在本机，直接通过 SSH 连接你的服务器':
        'Credentials are stored encrypted on this device only; connects to your server directly over SSH',
    // ── 首页 ──
    '已断开连接': 'Disconnected',
    '已连接': 'Connected',
    '连接失败': 'Connection failed',
    '未连接': 'Not connected',
    '尚未连接服务器': 'Not connected to a server yet',
    '重试': 'Retry',
    '连接': 'Connect',
    '添加服务': 'Add service',
    '{name} 重启命令已执行': 'Restart command sent to {name}',
    '重启失败：{msg}': 'Restart failed: {msg}',
    '获取状态失败：{msg}': 'Failed to get status: {msg}',
    '已运行 {info}': 'Up for {info}',
    '正在重启，请稍候…': 'Restarting, please wait…',
    '已停止（退出码 {code}）': 'Stopped (exit code {code})',
    '未找到该{kind}，请检查配置': '{kind} not found, check the config',
    '状态：{state}': 'Status: {state}',
    '重启中…': 'Restarting…',
    '重启': 'Restart',
    '日志': 'Logs',
    '刷新状态': 'Refresh status',
    '编辑服务': 'Edit service',
    '删除服务': 'Delete service',
    '确认重启 {name}？': 'Restart {name}?',
    '将远程执行重启命令，服务会短暂离线。':
        'This will run the restart command remotely; the service will be offline briefly.',
    '取消': 'Cancel',
    '确认重启': 'Confirm restart',
    // ── 日志页 ──
    '（暂无日志）': '(no logs yet)',
    '获取日志失败：{err}': 'Failed to fetch logs: {err}',
    '日志已复制到剪贴板': 'Logs copied to clipboard',
    '{name} · 日志': '{name} · Logs',
    '自动': 'Auto',
    '拉取中…': 'Fetching…',
    '刷新日志': 'Refresh logs',
    '滚动到底部': 'Scroll to bottom',
    // ── WebUI 页 ──
    '还没有打开的 WebUI': 'No WebUI open yet',
    '通过 SSH 隧道安全访问 AstrBot / NapCat 后台，\n可同时打开多个会话':
        'Access AstrBot / NapCat panels securely over an SSH tunnel.\nMultiple sessions can stay open at once',
    '打开 WebUI': 'Open WebUI',
    '无法打开 {name} 的 WebUI\n\n{err}': "Could not open {name}'s WebUI\n\n{err}",
    '关闭会话': 'Close session',
    '正在通过 SSH 隧道连接 {name}…': 'Connecting to {name} over the SSH tunnel…',
    '选择要打开 WebUI 的服务': 'Choose a service to open its WebUI',
    '端口 {port}': 'Port {port}',
    // ── 状态胶囊 ──
    '运行中': 'Running',
    '重启中': 'Restarting',
    '已停止': 'Stopped',
    '出错': 'Error',
    '未找到': 'Missing',
    '未启动': 'Created',
    '已暂停': 'Paused',
    '异常': 'Dead',
    '未运行': 'Inactive',
    '失败': 'Failed',
    // ── 服务编辑器 ──
    '请选择 1:1 比例的图片': 'Please select a 1:1 square image',
    '选择图片失败：{err}': 'Failed to pick image: {err}',
    '服务器上没有检测到任何容器': 'No containers detected on the server',
    '请填写显示名与服务名': 'Please fill in display name and service name',
    '显示名': 'Display name',
    '例如 AstrBot': 'e.g. AstrBot',
    '管理方式': 'Management type',
    '容器名': 'Container name',
    'Compose 服务名': 'Compose service name',
    'systemd 服务名': 'systemd service name',
    '例如 astrbot（可用下方“检测”自动获取）':
        'e.g. astrbot (use "Detect" below to find it automatically)',
    '例如 astrbot': 'e.g. astrbot',
    '检测': 'Detect',
    'compose 文件路径（可留空）': 'compose file path (optional)',
    '例如 /opt/astrbot/docker-compose.yml': 'e.g. /opt/astrbot/docker-compose.yml',
    'WebUI 端口（APP 内通过 SSH 隧道打开）': 'WebUI port (opened in-app via SSH tunnel)',
    'AstrBot 默认 6185，NapCat 默认 6099':
        'AstrBot defaults to 6185, NapCat to 6099',
    'WebUI 访问路径（可留空）': 'WebUI path (optional)',
    '例如 /webui?token=xxx（NapCat 开启 token 时填写）':
        'e.g. /webui?token=xxx (for NapCat when token is enabled)',
    '保存': 'Save',
    '选择容器': 'Select a container',
    // ── 服务类型 ──
    'Docker 容器': 'Docker container',
    'systemd 服务': 'systemd service',
    '容器': 'Container',
    '服务': 'Service',
    // ── 设置页 ──
    '背景': 'Background',
    '自定义背景图片': 'Custom background image',
    '已使用自定义背景': 'Custom background in use',
    '当前使用默认渐变背景': 'Using the default gradient background',
    '选择图片': 'Choose image',
    '恢复默认': 'Restore default',
    '界面图标（顶部）': 'App icon (top)',
    '仅接受 1:1 比例的图片': 'Only 1:1 square images are accepted',
    '更换图标': 'Change icon',
    '背景已更新': 'Background updated',
    '界面图标已更新': 'App icon updated',
    '显示': 'Display',
    '语言': 'Language',
    '中文': '中文',
    '切换界面显示语言，立即生效': 'Switch the UI language; takes effect immediately',
    '毛玻璃背景模糊': 'Frosted glass blur',
    '整页单层模糊，滚动稳定且流畅':
        'A single full-page blur layer, stable and smooth while scrolling',
    '浅色模式': 'Light mode',
    '全局切换为浅色界面': 'Switch the whole app to a light theme',
    '模糊强度': 'Blur intensity',
    '刷新率（帧率）': 'Refresh rate (FPS)',
    '按应用锁定帧率，切换后立即生效；无限制则跟随系统':
        'Locks the app refresh rate; takes effect immediately. Unlimited follows the system',
    '无限制': 'Unlimited',
    '管理': 'Management',
    '状态自动刷新': 'Auto refresh status',
    '关闭': 'Off',
    '{n} 秒': '{n}s',
    '日志默认行数': 'Default log lines',
    '{n} 行': '{n} lines',
    '日志字号': 'Log font size',
    '关于': 'About',
    '作者：星月晓梦_07': 'Author: 星月晓梦_07',
    '通过 SSH 直连远程管理服务器上的 AstrBot 与 NapCat。连接凭据仅加密保存在本机，所有操作经 SSH 加密传输。':
        'Remotely manage AstrBot and NapCat on your server over a direct SSH connection. Credentials are stored encrypted on this device only; all operations go over encrypted SSH.',
    // ── 服务/SSH 错误 ──
    '基础命令执行失败': 'Basic command failed',
    'Docker：未检测到': 'Docker: not detected',
    '无法获取容器列表（Docker 不可用？）':
        'Could not list containers (Docker unavailable?)',
    '无法获取容器状态': 'Could not get container status',
    '无法查询 Compose 服务': 'Could not query Compose service',
    '重启失败（退出码 {code}）': 'Restart failed (exit code {code})',
    '无法获取日志': 'Could not fetch logs',
    '命令执行超时': 'Command timed out',
    '连接被拒绝：请检查 IP/端口，以及阿里云安全组是否放行 SSH 端口':
        'Connection refused: check the IP/port and whether the cloud security group allows the SSH port',
    '连接超时：请检查网络与服务器地址':
        'Connection timed out: check the network and the server address',
    '无法解析主机名，请检查服务器地址':
        'Could not resolve the hostname, check the server address',
    'SSH 认证失败：请检查用户名、密码或私钥':
        'SSH authentication failed: check the username, password or private key',
    'SSH 会话已断开，请重新连接': 'SSH session closed, please reconnect',
    '缺少服务器配置': 'Missing server configuration',
    '服务器 127.0.0.1:{port} 端口未监听\n请确认 {name} 的 WebUI 已开启，或端口配置有误':
        "Server 127.0.0.1:{port} is not listening\nMake sure {name}'s WebUI is enabled, or the port is misconfigured",
    '页面加载失败': 'Page failed to load',
    // ── 时长格式化 ──
    '未知': 'unknown',
    '刚刚': 'just now',
    '{n} 分钟': '{n}m',
    '{n} 小时 {m} 分钟': '{n}h {m}m',
    '{n} 天 {h} 小时': '{n}d {h}h',
  };
}
