import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/repositories/market_catalog_repository.dart';
import '../../domain/models/market_category.dart';
import '../../domain/models/market_product.dart';
import '../../infrastructure/repositories/preview_market_catalog_repository.dart';

final marketCatalogRepositoryProvider = Provider<MarketCatalogRepository>((
  ref,
) {
  return PreviewMarketCatalogRepository();
});

final marketCatalogProvider = FutureProvider.autoDispose<List<MarketProduct>>((
  ref,
) {
  return ref.watch(marketCatalogRepositoryProvider).loadProducts();
});

final selectedMarketCategoryProvider =
    StateProvider.autoDispose<MarketCategory?>((ref) => null);
