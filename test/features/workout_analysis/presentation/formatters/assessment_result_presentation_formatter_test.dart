import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/formatters/assessment_result_presentation_formatter.dart';

void main() {
  const turkish = AppLocalizations(Locale('tr'));
  const english = AppLocalizations(Locale('en'));

  test('rounds camera-derived degrees and marks them as approximate', () {
    expect(
      AssessmentResultPresentationFormatter.degrees(turkish, 84.7),
      'Yaklaşık 85°',
    );
    expect(
      AssessmentResultPresentationFormatter.degrees(english, 12.3),
      'About 12°',
    );
  });

  test('rounds scores and durations without exposing false precision', () {
    expect(
      AssessmentResultPresentationFormatter.score(turkish, 86.6),
      'Yaklaşık 87 / 100',
    );
    expect(
      AssessmentResultPresentationFormatter.duration(
        turkish,
        const Duration(milliseconds: 5550),
      ),
      'Yaklaşık 6 sn',
    );
  });

  test('uses an unavailable marker for missing or non-finite values', () {
    expect(
      AssessmentResultPresentationFormatter.degrees(turkish, null),
      AssessmentResultPresentationFormatter.unavailableValue,
    );
    expect(
      AssessmentResultPresentationFormatter.degrees(turkish, double.nan),
      AssessmentResultPresentationFormatter.unavailableValue,
    );
    expect(
      AssessmentResultPresentationFormatter.score(turkish, double.infinity),
      AssessmentResultPresentationFormatter.unavailableValue,
    );
  });
}
