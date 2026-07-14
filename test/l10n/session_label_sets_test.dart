import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_en.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_zh.dart';

void main() {
  // The session label set swaps as a whole per locale (DESIGN.md i18n rule);
  // a mixed set (e.g. the pre-v0.4 "Night" next to "Overnight") is a bug.
  test('en session labels are the whole Pre/Post/Overnight set', () {
    final en = AppLocalizationsEn();
    expect(en.preMarketSessionLabel, 'Pre');
    expect(en.postMarketSessionLabel, 'Post');
    expect(en.overnightSessionLabel, 'Overnight');
  });

  test('zh session labels are the whole 盘前/盘后/夜盘 set', () {
    final zh = AppLocalizationsZh();
    expect(zh.preMarketSessionLabel, '盘前');
    expect(zh.postMarketSessionLabel, '盘后');
    expect(zh.overnightSessionLabel, '夜盘');
  });
}
