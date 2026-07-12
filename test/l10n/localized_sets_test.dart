import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_en.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_zh.dart';
import 'package:tuantuan_stock/l10n/localized_sets.dart';

void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();

  const apple = Stock(
    symbol: 'AAPL',
    name: 'Apple Inc',
    zhName: '苹果公司',
    exchange: 'NMS',
  );
  const amd = Stock(
    symbol: 'ZZZZ',
    name: 'Advanced Micro Devices Inc',
    zhName: '超微半导体有限公司',
    exchange: 'NMS',
  );
  const noZhName = Stock(
    symbol: 'ZZZZ',
    name: 'Costco Wholesale Corp',
    exchange: 'NMS',
  );

  group('stockTitle', () {
    test('curated symbol resolves to the colloquial short name', () {
      expect(en.stockTitle(apple, 'AAPL'), 'Apple');
      expect(zh.stockTitle(apple, 'AAPL'), '苹果');
    });

    test('unmapped symbol resolves to the de-suffixed provider name', () {
      expect(en.stockTitle(amd, 'ZZZZ'), 'Advanced Micro Devices');
      expect(zh.stockTitle(amd, 'ZZZZ'), '超微半导体');
    });

    test('a Chinese locale without a zh name strips the English name', () {
      expect(zh.stockTitle(noZhName, 'ZZZZ'), 'Costco Wholesale');
    });

    test('no identity resolves to the ticker', () {
      expect(en.stockTitle(null, 'AAPL'), 'AAPL');
      expect(zh.stockTitle(null, 'AAPL'), 'AAPL');
    });
  });

  group('stockFullTitle', () {
    test('keeps the full provider name for search results', () {
      expect(en.stockFullTitle(apple, 'AAPL'), 'Apple Inc');
      expect(zh.stockFullTitle(apple, 'AAPL'), '苹果公司');
      expect(en.stockFullTitle(null, 'AAPL'), 'AAPL');
    });
  });
}
