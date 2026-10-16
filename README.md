# 🤖 astrbot助手

一个**毛玻璃（Frosted Glass）风格**的 Android 手机 App，通过手机 **直连 SSH** 远程管理部署在云服务器上的 **AstrBot** 与 **NapCat**：查看状态、远程重启、查看日志、APP 内打开 WebUI。

- 🌐 中英双语 · ☀️ 深浅色模式 · 🔒 凭据加密存储
- 无需在服务器上部署任何东西，凭 SSH 直连即可管理

## ✨ 功能

- 📡 **SSH 直连**：App 直接通过 SSH 执行命令，支持密码 / 私钥登录
- 🟢 **状态监控**：运行中 / 已停止 / 重启中，运行时长、退出码、镜像信息
- 📊 **服务器资源监控**：CPU / 内存 / 磁盘占用一目了然
- 🔄 **一键远程重启**：支持 `docker restart`、`docker compose restart`、`systemctl restart` 三种方式
- ⚡ **服务器电源控制**：重启服务器 / 强制关机（带强确认）
- 📜 **实时日志**：终端风格日志面板，自动刷新（最短 5 秒）、一键复制、长按选词
- 🤖 **AI 日志分析**：接入 OpenAI 兼容大模型（DeepSeek / 通义 / Moonshot…），一键或选中分析报错原因
- 🌐 **APP 内打开 WebUI**：通过 SSH 隧道安全访问网页后台，**无需在公网开放端口**；也支持直接打开自定义网址
- 📁 **文件管理**：SFTP 浏览服务器文件，上传 / 下载 / 分享 / 复制 / 移动 / 重命名 / 新建文件夹 / 文本预览
- 🔍 **容器自动检测**：一键列出服务器上的所有容器，自动填入容器名
- ➕ **任意服务**：除了默认的 AstrBot / NapCat，可自由添加其他容器 / Compose / systemd 服务
- 🎨 **毛玻璃 UI**：高斯模糊卡片 + 渐变背景，支持浅色 / 深色模式
- ✨ **轻量动效**：页面滑入淡入、仪表盘卡片错峰入场、按钮按压回弹、状态与资源进度平滑过渡；跟随系统关闭动画设置
- 🧭 **透明悬浮导航**：紧凑居中的毛玻璃胶囊，页面内容可延伸至胶囊两侧；四个标签共享同一背景并统一横向切换，WebUI 同步移动，按钮快速轻点也会播放按压回弹
- 🌐 **中英双语**：设置内一键切换界面语言
- ⚡ **刷新率设置**：按应用锁定 30 / 60 / 120 帧或无限制
- 🖼️ **自定义背景与界面图标**：本地图片一键更换
- 🔄 **自动更新检测**：启动时自动检查 GitHub Releases，有新版本弹窗提示
- 🔐 **凭据安全**：连接信息使用 Android Keystore 加密存储在本机

## 📱 安装

1. 从 [Releases](../../releases) 下载最新 `.apk` 安装包
2. 传到手机（微信/QQ/网盘均可），点击安装并允许「安装未知来源应用」

## 🚀 使用

1. 打开 App，填写：
   - **服务器地址**：云服务器公网 IP 或域名
   - **SSH 端口**：默认 `22`
   - **用户名**：默认 `root`
   - **密码**：服务器 root 密码（或切换为「私钥登录」粘贴 PEM 私钥）
   - 非 root 用户请勾选「命令前加 sudo」
2. 点击「**连接并保存**」，成功后自动进入仪表盘
3. 首页卡片上：
   - 「**远程重启**」→ 确认后重启对应服务
   - 「**查看日志**」→ 进入终端风格日志页
   - 「**WebUI**」→ 经 SSH 隧道打开网页后台
   - 下拉页面可刷新全部状态
4. 若容器名不是默认的 `astrbot` / `napcat`：卡片右上角「⋯」→「编辑服务」→「检测」自动列出容器，或点首页底部「添加服务」

## 🔒 安全建议

- 在云安全组中限制 SSH 端口（22）仅允许你的常用 IP 访问
- 推荐使用**密钥登录**：服务器配置好公钥后，App 选择私钥登录并粘贴私钥文本
- 服务器上建议开启 SSH 防爆破（如 fail2ban、密钥-only 登录）

## 🛠 从源码构建

```bash
flutter pub get
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk
```

> Windows 上一键构建脚本见 `tools/build-app.ps1`（可选，自动配置国内镜像并应用图标）。

## 🗂 项目结构

```
app/
├── android/                         # Android 工程（已含必要补丁）
├── lib/
│   ├── main.dart                    # 入口：语言/主题同步、生命周期监听（后台自动重连）
│   ├── version.dart                 # 应用版本号（唯一来源）
│   ├── l10n.dart                    # 中英双语（轻量查表实现）
│   ├── theme.dart                   # 主题与配色（深浅色自适应）
│   ├── models/
│   │   ├── config.dart              # 服务器/服务配置模型
│   │   └── settings.dart            # 应用设置
│   ├── services/
│   │   ├── ssh.dart                 # SSH 连接与端口隧道（dartssh2）
│   │   ├── manager.dart             # 状态/重启/日志/电源命令
│   │   ├── sftp_manager.dart        # SFTP 远程文件操作
│   │   ├── ai_analyze.dart          # AI 日志分析（OpenAI 兼容）
│   │   ├── update_check.dart        # GitHub Releases 更新检测
│   │   ├── storage.dart             # 安全存储（Keystore）
│   │   ├── webui_session.dart       # WebUI 会话（SSH 隧道/自定义网址）
│   │   └── frame_rate.dart          # 帧率控制（MethodChannel）
│   ├── state/app_state.dart         # 全局状态（含回到前台自动恢复）
│   ├── screens/
│   │   ├── connection_screen.dart   # 连接配置页
│   │   ├── home_screen.dart         # 仪表盘（资源监控/电源控制）
│   │   ├── logs_screen.dart         # 日志页（AI 分析）
│   │   ├── files_screen.dart        # SFTP 文件管理
│   │   ├── webui_page.dart          # WebUI 多会话页
│   │   ├── settings_screen.dart     # 设置页
│   │   └── main_shell.dart          # 底部导航框架
│   └── widgets/
│       ├── glass.dart               # 毛玻璃组件（卡片/按钮/输入框）
│       ├── background.dart          # 渐变背景
│       ├── service_editor.dart      # 服务编辑对话框
│       ├── service_icon.dart        # 服务图标
│       └── update_dialog.dart       # 更新提示弹窗
└── pubspec.yaml
```


## 📦 技术栈

- Flutter 3.29（Dart 3.7）
- [dartssh2](https://pub.dev/packages/dartssh2)（纯 Dart SSH2 客户端）
- flutter_secure_storage（凭据加密存储）
- provider（状态管理）
- webview_flutter（内嵌 WebUI）

## 📄 许可与作者

- 作者：**星月晓梦_07**
- 许可证：[MIT](LICENSE)
