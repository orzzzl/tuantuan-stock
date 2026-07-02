import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuantuan_stock/data/watchlist/prefs_watchlist_repository.dart';
import 'package:tuantuan_stock/domain/repositories/watchlist_repository.dart';

final watchlistRepositoryProvider = Provider<WatchlistRepository>(
  (ref) => PrefsWatchlistRepository(SharedPreferencesAsync()),
);

/// The live symbol list for screens: emits now and after every add/remove.
final watchlistProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(watchlistRepositoryProvider).watch(),
);
