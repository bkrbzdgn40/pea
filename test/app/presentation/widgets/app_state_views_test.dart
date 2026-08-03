import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_state_views.dart';

void main() {
  testWidgets('AppLoadingView renders the loading indicator and message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppLoadingView(message: 'Yukleniyor')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Yukleniyor'), findsOneWidget);
  });

  testWidgets('AppErrorView renders the message and action callback', (
    WidgetTester tester,
  ) async {
    var actionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppErrorView(
            title: 'Hata',
            message: 'Bir seyler ters gitti',
            actionLabel: 'Tekrar Dene',
            onAction: () => actionCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('Hata'), findsOneWidget);
    expect(find.text('Bir seyler ters gitti'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);

    await tester.tap(find.text('Tekrar Dene'));
    await tester.pump();

    expect(actionCount, 1);
  });

  testWidgets('AppEmptyView renders inline empty content and action callback', (
    WidgetTester tester,
  ) async {
    var actionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyView(
            title: 'Bos',
            message: 'Henuz veri yok',
            actionLabel: 'Yenile',
            onAction: () => actionCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('Bos'), findsOneWidget);
    expect(find.text('Henuz veri yok'), findsOneWidget);

    await tester.tap(find.text('Yenile'));
    await tester.pump();

    expect(actionCount, 1);
  });

  testWidgets('AppRootStateScaffold remains scrollable with large text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: const AppRootStateScaffold(
            child: AppErrorView(
              title: 'Oturum hazırlanamadı',
              message:
                  'Bu uzun hata açıklaması dar bir ekranda erişilebilir kalmalıdır.',
              actionLabel: 'Tekrar Dene',
              onAction: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
