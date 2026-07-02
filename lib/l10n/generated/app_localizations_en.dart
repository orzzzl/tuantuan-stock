// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TuanTuan Stocks';

  @override
  String get watchlistTitle => 'Watchlist';

  @override
  String get watchlistPlaceholder => 'Watchlist placeholder';

  @override
  String get openDetailButton => 'Open stock detail';

  @override
  String get openSearchButton => 'Open search';

  @override
  String detailTitle(String symbol) {
    return '$symbol detail';
  }

  @override
  String detailPlaceholder(String symbol) {
    return 'Stock detail placeholder for $symbol';
  }

  @override
  String get searchTitle => 'Search';

  @override
  String get searchPlaceholder => 'Search placeholder';

  @override
  String get backButton => 'Back';
}
