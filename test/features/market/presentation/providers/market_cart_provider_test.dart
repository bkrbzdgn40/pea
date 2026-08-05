import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_cart_provider.dart';

void main() {
  const product = MarketProduct(
    id: 'phone_tripod',
    category: MarketCategory.setup,
    price: Money(minorUnits: 79900, currencyCode: 'TRY'),
  );

  test('adds the same product by increasing its quantity', () {
    final controller = MarketCartController();
    addTearDown(controller.dispose);

    controller.add(product);
    controller.add(product);

    expect(controller.state.lines, hasLength(1));
    expect(controller.state.quantityFor(product.id), 2);
    expect(controller.state.itemCount, 2);
    expect(controller.state.subtotal.minorUnits, 159800);
  });

  test('increments, decrements, and removes cart lines', () {
    final controller = MarketCartController();
    addTearDown(controller.dispose);

    controller.add(product);
    controller.increment(product.id);
    expect(controller.state.quantityFor(product.id), 2);

    controller.decrement(product.id);
    expect(controller.state.quantityFor(product.id), 1);

    controller.decrement(product.id);
    expect(controller.state.isEmpty, isTrue);

    controller.add(product);
    controller.remove(product.id);
    expect(controller.state.isEmpty, isTrue);
  });

  test('clears the cart after a verified payment', () {
    final controller = MarketCartController();
    addTearDown(controller.dispose);

    controller.add(product);
    controller.clear();

    expect(controller.state.isEmpty, isTrue);
  });
}
