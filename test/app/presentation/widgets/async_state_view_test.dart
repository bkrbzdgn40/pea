import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/async_state_view.dart';

void main() {
  testWidgets('dispatches AsyncLoading to the shared loading view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncStateView<String>(
            value: const AsyncValue<String>.loading(),
            dataBuilder: (_, data) => Text(data),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('dispatches AsyncError to the shared error view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncStateView<String>(
            value: AsyncValue<String>.error(
              Exception('boom'),
              StackTrace.empty,
            ),
            dataBuilder: (_, data) => Text(data),
          ),
        ),
      ),
    );

    expect(find.text('Veriler yuklenemedi.'), findsOneWidget);
  });

  testWidgets('dispatches AsyncData to the data builder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncStateView<String>(
            value: const AsyncValue<String>.data('hazir'),
            dataBuilder: (_, data) => Text('Veri: $data'),
          ),
        ),
      ),
    );

    expect(find.text('Veri: hazir'), findsOneWidget);
  });
}
