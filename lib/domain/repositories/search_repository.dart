import 'package:tuantuan_stock/domain/models/stock.dart';

/// Symbol lookup by ticker or company name. Implementations throw
/// [DataFailure] subtypes on error.
abstract interface class SearchRepository {
  /// Stocks matching [query], best match first; empty list for no matches.
  Future<List<Stock>> search(String query);
}
