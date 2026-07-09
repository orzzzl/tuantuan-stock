import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/data/market/company_logos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('companyLogoAsset', () {
    test('maps a curated symbol to its bundled asset path', () {
      expect(companyLogoAsset('AAPL'), 'assets/logos/aapl.png');
      expect(companyLogoAsset('BABA'), 'assets/logos/baba.png');
    });

    test('unmapped symbols and indexes resolve to null', () {
      expect(companyLogoAsset('ZZZZ'), isNull);
      expect(companyLogoAsset('^GSPC'), isNull);
    });

    test('every mapped entry points at a committed asset file', () {
      expect(companyLogoAssets, isNotEmpty);
      for (final MapEntry(:key, :value) in companyLogoAssets.entries) {
        expect(
          File(value).existsSync(),
          isTrue,
          reason: '$key maps to $value which is not in the repo',
        );
      }
    });

    test('every mapped entry loads from the flutter asset bundle', () async {
      // Catches a missing pubspec assets declaration, not just a missing file.
      for (final MapEntry(:key, :value) in companyLogoAssets.entries) {
        final bytes = await rootBundle.load(value);
        expect(bytes.lengthInBytes, greaterThan(0), reason: '$key -> $value');
      }
    });

    test('every bundled logo file has a map entry', () {
      final files = Directory(
        'assets/logos',
      ).listSync().whereType<File>().map((f) => f.path).toSet();
      final mapped = companyLogoAssets.values.toSet();
      expect(files.difference(mapped), isEmpty, reason: 'orphaned asset');
    });
  });
}
