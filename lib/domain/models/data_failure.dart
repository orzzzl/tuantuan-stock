/// Typed failure thrown by repository implementations so callers can react
/// per cause instead of parsing provider-specific errors.
sealed class DataFailure implements Exception {
  const DataFailure(this.message);

  /// Human-oriented detail for logs; never shown raw in the UI.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The provider could not be reached (offline, DNS, timeout).
final class NetworkFailure extends DataFailure {
  const NetworkFailure(super.message);
}

/// The provider is throttling us; back off before retrying.
final class RateLimitFailure extends DataFailure {
  const RateLimitFailure(super.message);
}

/// The provider rejected our credentials (e.g. an expired cookie/crumb pair).
final class AuthFailure extends DataFailure {
  const AuthFailure(super.message);
}

/// The requested symbol does not exist.
final class NotFoundFailure extends DataFailure {
  const NotFoundFailure(super.message);
}
