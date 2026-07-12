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
