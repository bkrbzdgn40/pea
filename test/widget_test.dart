import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_estimation_app/app/app.dart';

void main() {
  testWidgets('app opens the demo home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PoseAnalysisApp()));

    expect(find.text('Yapay Zeka Destekli Spor Analizi'), findsOneWidget);
    expect(find.text('Analize Başla'), findsOneWidget);
  });
}
