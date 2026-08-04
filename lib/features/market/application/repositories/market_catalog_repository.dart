import '../../domain/models/market_product.dart';

abstract interface class MarketCatalogRepository {
  Future<List<MarketProduct>> loadProducts();
}
