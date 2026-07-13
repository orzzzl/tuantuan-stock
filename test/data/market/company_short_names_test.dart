import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/data/market/company_logos.dart';
import 'package:tuantuan_stock/data/market/company_short_names.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_race_providers.dart';

void main() {
  group('companyShortName', () {
    test('maps a curated symbol to its colloquial pair', () {
      expect(companyShortName('AAPL'), (zh: '苹果', en: 'Apple'));
      expect(companyShortName('^GSPC'), (zh: '标普500', en: 'S&P 500'));
    });

    test('unmapped symbols resolve to null', () {
      expect(companyShortName('ZZZZ'), isNull);
    });

    test('covers every bundled-logo symbol and the index strip', () {
      final missing = {
        ...companyLogoAssets.keys,
        ...indexStripSymbols,
      }.where((symbol) => !companyShortNames.containsKey(symbol));
      expect(missing, isEmpty, reason: 'symbols without a curated short name');
    });

    test('every entry is non-empty and unique per language', () {
      final zhSeen = <String, String>{};
      final enSeen = <String, String>{};
      for (final MapEntry(:key, :value) in companyShortNames.entries) {
        expect(value.zh.trim(), isNotEmpty, reason: '$key zh is empty');
        expect(value.en.trim(), isNotEmpty, reason: '$key en is empty');
        expect(
          zhSeen,
          isNot(contains(value.zh)),
          reason: '$key zh duplicates ${zhSeen[value.zh]}',
        );
        expect(
          enSeen,
          isNot(contains(value.en)),
          reason: '$key en duplicates ${enSeen[value.en]}',
        );
        zhSeen[value.zh] = key;
        enSeen[value.en] = key;
      }
    });
  });

  group('companyShortName (ETFs, task 28)', () {
    test('maps the owner-reported ETF rows to punchy pairs', () {
      expect(companyShortName('TQQQ'), (zh: '纳指三倍做多', en: 'UltraPro QQQ'));
      expect(companyShortName('SSO'), (zh: '标普两倍做多', en: 'Ultra S&P 500'));
      expect(companyShortName('YINN'), (zh: '中国三倍做多', en: 'China Bull 3X'));
      expect(companyShortName('MOAT'), (zh: '宽护城河 ETF', en: 'Wide Moat ETF'));
      expect(companyShortName('SPY'), (zh: '标普500 ETF', en: 'SPDR S&P 500'));
    });

    test('same-index funds stay distinguishable via the issuer', () {
      expect(companyShortName('VOO'), (zh: '先锋标普500', en: 'Vanguard S&P 500'));
      expect(companyShortName('IVV'), (zh: '安硕标普500', en: 'iShares S&P 500'));
    });
  });

  group('shortenCompanyName (en ETF fallback, task 28)', () {
    test('strips a leading issuer/trust prefix', () {
      expect(
        shortenCompanyName('ProShares Trust Ultra S&P 500', chinese: false),
        'Ultra S&P 500',
      );
      expect(
        shortenCompanyName(
          'Direxion Shares ETF Trust Daily FTSE China Bull 3X Shares',
          chinese: false,
        ),
        'FTSE China Bull 3X',
      );
    });

    test('sheds stacked issuer layers and title-case artifacts', () {
      expect(
        shortenCompanyName(
          'Vaneck Etf Tr Vaneck Morningstar Wide Moat ETF',
          chinese: false,
        ),
        'Morningstar Wide Moat ETF',
      );
    });

    test('collapses ETF Trust and Select Sector SPDR wrappers', () {
      expect(
        shortenCompanyName(
          'State Street SPDR S&P 500 ETF Trust',
          chinese: false,
        ),
        'S&P 500 ETF',
      );
      expect(
        shortenCompanyName(
          'Technology Select Sector SPDR Fund',
          chinese: false,
        ),
        'Technology',
      );
    });

    test('leaves company names alone, even fund-marker lookalikes', () {
      expect(
        shortenCompanyName('Northern Trust Corp', chinese: false),
        'Northern Trust',
      );
      expect(
        shortenCompanyName('Fidelity National Financial Inc', chinese: false),
        'Fidelity National Financial',
      );
    });

    test('never strips to empty', () {
      expect(
        shortenCompanyName('ProShares Trust', chinese: false),
        'ProShares Trust',
      );
    });
  });

  group('shortenCompanyName (zh ETF fallback, task 28)', () {
    test('strips the trailing -发行商 tail', () {
      expect(
        shortenCompanyName('标普500指数ETF-SPDR', chinese: true),
        '标普500指数ETF',
      );
      expect(
        shortenCompanyName('纳斯达克100三倍做多ETF-ProShares', chinese: true),
        '纳斯达克100三倍做多ETF',
      );
    });

    test('strips a leading latin issuer', () {
      expect(
        shortenCompanyName('VanEck Vectors晨星宽护城河ETF', chinese: true),
        '晨星宽护城河ETF',
      );
    });

    test('non-fund zh names keep their hyphen tails', () {
      expect(shortenCompanyName('伯克希尔-B', chinese: true), '伯克希尔-B');
    });
  });

  group('shortenCompanyName (en)', () {
    test('strips a single legal suffix', () {
      expect(
        shortenCompanyName('Advanced Micro Devices Inc', chinese: false),
        'Advanced Micro Devices',
      );
      expect(
        shortenCompanyName('Exxon Mobil Corporation', chinese: false),
        'Exxon Mobil',
      );
    });

    test('strips stacked suffixes and leftover separators', () {
      expect(
        shortenCompanyName('Booking Holdings Inc', chinese: false),
        'Booking',
      );
      expect(
        shortenCompanyName('JPMorgan Chase & Co', chinese: false),
        'JPMorgan Chase',
      );
    });

    test('strips share-class tails', () {
      expect(
        shortenCompanyName('Alphabet Inc-CL A', chinese: false),
        'Alphabet',
      );
      expect(
        shortenCompanyName('Berkshire Hathaway Inc Class B', chinese: false),
        'Berkshire Hathaway',
      );
    });

    test('never strips leading words or the whole name', () {
      expect(shortenCompanyName('Inc', chinese: false), 'Inc');
      expect(
        shortenCompanyName('Costco Wholesale', chinese: false),
        'Costco Wholesale',
      );
    });
  });

  group('shortenCompanyName (zh)', () {
    test('strips the legal tail but keeps 集团', () {
      expect(shortenCompanyName('阿里巴巴集团控股有限公司', chinese: true), '阿里巴巴集团');
      expect(shortenCompanyName('英伟达公司', chinese: true), '英伟达');
      expect(shortenCompanyName('京东集团股份有限公司', chinese: true), '京东集团');
    });

    test('never strips the whole name', () {
      expect(shortenCompanyName('公司', chinese: true), '公司');
      expect(shortenCompanyName('特斯拉', chinese: true), '特斯拉');
    });
  });
}
