import 'package:flutter_test/flutter_test.dart';

import 'package:astrbot_manager/l10n.dart';

void main() {
  test('L10n 中文默认返回原文', () {
    L10n.lang = 'zh';
    expect(L10n.t('连接并保存'), '连接并保存');
    expect(L10n.t('连接失败：{err}', {'err': '测试'}), '连接失败：测试');
  });

  test('L10n 英文查表替换', () {
    L10n.lang = 'en';
    expect(L10n.t('连接并保存'), 'Connect & save');
    expect(L10n.t('设置'), 'Settings');
    expect(L10n.t('连接失败：{err}', {'err': 'boom'}), 'Connection failed: boom');
  });

  test('L10n 未收录的 key 回退原文', () {
    L10n.lang = 'en';
    expect(L10n.t('这条文案没有翻译'), '这条文案没有翻译');
  });
}
