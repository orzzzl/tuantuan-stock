import 'package:tuantuan_stock/domain/models/stock.dart';

/// Identity lookups for symbols the app already knows (e.g. the saved
/// watchlist), as opposed to free-text search. Implementations throw
/// [DataFailure] subtypes on error.
abstract interface class StockRepository {
  /// Identities for [symbols] in one provider round-trip, keyed by symbol.
  /// Unknown symbols are absent from the map.
  Future<Map<String, Stock>> stocks(List<String> symbols);
}
