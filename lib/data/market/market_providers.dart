import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tuantuan_stock/data/market/yahoo_client.dart';
import 'package:tuantuan_stock/data/market/yahoo_company_profiles.dart';
import 'package:tuantuan_stock/data/market/yahoo_quote_repository.dart';
import 'package:tuantuan_stock/data/market/yahoo_search_repository.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';
import 'package:tuantuan_stock/domain/repositories/search_repository.dart';

final _httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final _yahooClientProvider = Provider<YahooClient>(
  (ref) => YahooClient(httpClient: ref.watch(_httpClientProvider)),
);

final _companyProfilesProvider = Provider<YahooCompanyProfiles>(
  (ref) => YahooCompanyProfiles(ref.watch(_yahooClientProvider)),
);

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => YahooQuoteRepository(ref.watch(_yahooClientProvider)),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => YahooSearchRepository(
    ref.watch(_yahooClientProvider),
    ref.watch(_companyProfilesProvider),
  ),
);
