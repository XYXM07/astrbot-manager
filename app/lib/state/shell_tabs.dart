import 'package:flutter/foundation.dart';

/// 底部导航栏当前页索引（供各页面互相跳转）
class ShellTabs {
  ShellTabs._();
  static final ValueNotifier<int> index = ValueNotifier<int>(0);
}
