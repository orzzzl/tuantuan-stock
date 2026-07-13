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

  const moat = Stock(
    symbol: 'MOAT',
    name: 'Vaneck Etf Tr Vaneck Morningstar Wide Moat ETF',
    zhName: 'VanEck Vectors晨星宽护城河ETF',
    exchange: 'PCX',
  );

  group('stockSubtitle (task 28)', () {
    const uncuratedEtf = Stock(
      symbol: 'ZZZZ',
      name: 'ProShares Trust Ultra Something',
      zhName: '某指数ETF-ProShares',
      exchange: 'PCX',
    );

    test('en locale resolves the zh line like stockTitle', () {
      expect(en.stockSubtitle(apple, 'AAPL'), '苹果');
      expect(en.stockSubtitle(moat, 'MOAT'), '宽护城河 ETF');
      expect(en.stockSubtitle(uncuratedEtf, 'ZZZZ'), '某指数ETF');
    });

    test('zh locale keeps the ticker line', () {
      expect(zh.stockSubtitle(apple, 'AAPL'), 'AAPL');
    });

    test('no zh name falls back unchanged', () {
      expect(en.stockSubtitle(noZhName, 'ZZZZ'), 'ZZZZ');
    });
  });

  group('stockFullSubtitle', () {
    test('keeps the full zh line for search results', () {
      expect(en.stockFullSubtitle(moat, 'MOAT'), 'VanEck Vectors晨星宽护城河ETF');
      expect(zh.stockFullSubtitle(moat, 'MOAT'), 'MOAT');
      expect(en.stockFullSubtitle(null, 'AAPL'), 'AAPL');
    });
  });
}
