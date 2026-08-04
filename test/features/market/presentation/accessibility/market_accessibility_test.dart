import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_cart_line.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_product.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';
import 'package:pose_estimation_app/features/market/presentation/providers/market_cart_provider.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_cart_screen.dart';
import 'package:pose_estimation_app/features/market/presentation/screens/market_product_detail_screen.dart';
import 'package:pose_estimation_app/features/market/presentation/widgets/market_cart_action.dart';
import 'package:pose_estimation_app/features/market/presentation/widgets/market_product_card.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  const product = MarketProduct(
    id: 'phone_tripod',
    category: MarketCategory.setup,
    price: Money(minorUnits: 79900, currencyCode: 'TRY'),
  );

  testWidgets('product card exposes one concise actionable semantic label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpTestApp(
        tester,
        locale: const Locale('tr'),
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 224,
            child: MarketProductCard(product: product, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          RegExp(r'Telefon Tripodu, .*799.*Ürün detayını aç'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('market-product-phone_tripod')),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('cart action announces the current item count', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final initialCart = MarketCart(
        lines: const [MarketCartLine(product: product, quantity: 2)],
      );

      await pumpTestApp(
        tester,
        locale: const Locale('tr'),
        overrides: [
          marketCartProvider.overrideWith(
            (ref) => MarketCartController(initialState: initialCart),
          ),
        ],
        home: Scaffold(
          appBar: AppBar(actions: [MarketCartAction(onPressed: () {})]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Sepet, 2 ürün'), findsOneWidget);
      final cartActionSize = tester.getSize(
        find.byKey(const Key('market-cart-action')),
      );
      expect(cartActionSize.width, greaterThanOrEqualTo(48));
      expect(cartActionSize.height, greaterThanOrEqualTo(48));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('cart quantity controls name the affected product', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final initialCart = MarketCart(
        lines: const [MarketCartLine(product: product, quantity: 2)],
      );

      await pumpTestApp(
        tester,
        locale: const Locale('tr'),
        overrides: [
          marketCartProvider.overrideWith(
            (ref) => MarketCartController(initialState: initialCart),
          ),
        ],
        home: const MarketCartScreen(),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byKey(const Key('market-cart-scroll-view')),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);

      final removeKey = find.byKey(
        const ValueKey('market-cart-remove-phone_tripod'),
      );
      await tester.scrollUntilVisible(removeKey, 120, scrollable: scrollable);
      await tester.pump();
      expect(
        find.bySemanticsLabel('Telefon Tripodu ürününü sepetten kaldır'),
        findsOneWidget,
      );
      final removeSize = tester.getSize(removeKey);
      expect(removeSize.width, greaterThanOrEqualTo(48));
      expect(removeSize.height, greaterThanOrEqualTo(48));

      final decrementKey = find.byKey(
        const ValueKey('market-cart-decrement-phone_tripod'),
      );
      await tester.scrollUntilVisible(
        decrementKey,
        120,
        scrollable: scrollable,
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Telefon Tripodu adedini azalt'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Telefon Tripodu, 2 adet'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Telefon Tripodu adedini artır'),
        findsOneWidget,
      );

      for (final key in <Key>[
        const ValueKey('market-cart-decrement-phone_tripod'),
        const ValueKey('market-cart-increment-phone_tripod'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('product detail exposes its visual as an image', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpTestApp(
        tester,
        locale: const Locale('tr'),
        home: const MarketProductDetailScreen(product: product),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Telefon Tripodu ürün görseli'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
}
