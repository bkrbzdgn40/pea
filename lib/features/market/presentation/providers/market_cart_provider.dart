import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/market_cart.dart';
import '../../domain/models/market_cart_line.dart';
import '../../domain/models/market_product.dart';

final marketCartProvider =
    StateNotifierProvider<MarketCartController, MarketCart>((ref) {
      return MarketCartController();
    });

class MarketCartController extends StateNotifier<MarketCart> {
  MarketCartController({MarketCart initialState = const MarketCart()})
    : super(initialState);

  void add(MarketProduct product) {
    if (state.isNotEmpty && state.currencyCode != product.price.currencyCode) {
      throw ArgumentError.value(
        product.price.currencyCode,
        'product.price.currencyCode',
        'Cart items must use the same currency.',
      );
    }

    final currentQuantity = state.quantityFor(product.id);
    if (currentQuantity == 0) {
      state = state.copyWith(
        lines: <MarketCartLine>[
          ...state.lines,
          MarketCartLine(product: product, quantity: 1),
        ],
        currencyCode: product.price.currencyCode,
      );
      return;
    }

    _setQuantity(product.id, currentQuantity + 1);
  }

  void increment(String productId) {
    final currentQuantity = state.quantityFor(productId);
    if (currentQuantity == 0) {
      return;
    }
    _setQuantity(productId, currentQuantity + 1);
  }

  void decrement(String productId) {
    final currentQuantity = state.quantityFor(productId);
    if (currentQuantity <= 1) {
      remove(productId);
      return;
    }
    _setQuantity(productId, currentQuantity - 1);
  }

  void clear() {
    state = const MarketCart();
  }

  void remove(String productId) {
    state = state.copyWith(
      lines: state.lines
          .where((line) => line.product.id != productId)
          .toList(growable: false),
    );
  }

  void _setQuantity(String productId, int quantity) {
    state = state.copyWith(
      lines: state.lines
          .map(
            (line) => line.product.id == productId
                ? line.copyWith(quantity: quantity)
                : line,
          )
          .toList(growable: false),
    );
  }
}
