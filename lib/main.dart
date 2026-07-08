import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tuantuan_stock/app/tuantuan_stock_app.dart';

void main() {
  configureBundledFonts();
  runApp(const ProviderScope(child: TuanTuanStockApp()));
}

var _fontLicensesRegistered = false;

void configureBundledFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
  if (_fontLicensesRegistered) return;
  _fontLicensesRegistered = true;

  LicenseRegistry.addLicense(() async* {
    final baloo2License = await rootBundle.loadString(
      'assets/fonts/OFL-Baloo2.txt',
    );
    yield LicenseEntryWithLineBreaks(<String>['Baloo 2'], baloo2License);

    final zcoolLicense = await rootBundle.loadString(
      'assets/fonts/OFL-ZCOOLKuaiLe.txt',
    );
    yield LicenseEntryWithLineBreaks(<String>['ZCOOL KuaiLe'], zcoolLicense);
  });
}
