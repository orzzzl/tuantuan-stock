/// The on-device list of watched symbols, in user-defined order.
abstract interface class WatchlistRepository {
  /// Emits the full symbol list now and after every change.
  Stream<List<String>> watch();

  /// One-off snapshot of the current symbol list.
  Future<List<String>> symbols();

  /// Appends [symbol]; adding an already-watched symbol is a no-op.
  Future<void> add(String symbol);

  /// Removes [symbol]; removing an unknown symbol is a no-op.
  Future<void> remove(String symbol);
}
