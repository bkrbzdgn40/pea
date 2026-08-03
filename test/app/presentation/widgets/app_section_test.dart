import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_section.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';

void main() {
  testWidgets(
    'keeps heading, description, trailing action and content together',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: AppSection(
              title: 'Haftalik Gelisim',
              description: 'Ayni egzersizdeki son oturumlar',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Tumunu Gor'),
              ),
              child: const Text('section-content'),
            ),
          ),
        ),
      );

      expect(find.text('Haftalik Gelisim'), findsOneWidget);
      expect(find.text('Ayni egzersizdeki son oturumlar'), findsOneWidget);
      expect(find.text('Tumunu Gor'), findsOneWidget);
      expect(find.text('section-content'), findsOneWidget);
    },
  );
}
