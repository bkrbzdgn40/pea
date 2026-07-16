import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/analysis_visibility_gap_window.dart';

void main() {
  group('AnalysisVisibilityGapWindow', () {
    test('initially inactive', () {
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      expect(window.isActive, isFalse);
      expect(window.startedAt, isNull);
      expect(window.elapsedAt(DateTime(2026, 1, 1, 12)), isNull);
    });

    test('begin starts exactly one active window', () {
      final start = DateTime(2026, 1, 1, 12);
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      window.begin(start);

      expect(window.isActive, isTrue);
      expect(window.startedAt, start);
    });

    test('repeated begin does not silently reset the original start time', () {
      final start = DateTime(2026, 1, 1, 12);
      final later = start.add(const Duration(milliseconds: 500));
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      window.begin(start);
      window.begin(later);

      expect(window.startedAt, start);
      expect(window.elapsedAt(later), const Duration(milliseconds: 500));
    });

    test('elapsed duration is calculated correctly', () {
      final start = DateTime(2026, 1, 1, 12);
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      window.begin(start);

      expect(
        window.elapsedAt(start.add(const Duration(milliseconds: 750))),
        const Duration(milliseconds: 750),
      );
    });

    test('elapsed just below grace is inside grace', () {
      final start = DateTime(2026, 1, 1, 12);
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      window.begin(start);

      expect(
        window.isWithinGraceAt(start.add(const Duration(milliseconds: 1499))),
        isTrue,
      );
      expect(
        window.hasExpiredAt(start.add(const Duration(milliseconds: 1499))),
        isFalse,
      );
    });

    test('elapsed exactly equal to grace is expired', () {
      final start = DateTime(2026, 1, 1, 12);
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      window.begin(start);

      expect(
        window.isWithinGraceAt(start.add(const Duration(milliseconds: 1500))),
        isFalse,
      );
      expect(
        window.hasExpiredAt(start.add(const Duration(milliseconds: 1500))),
        isTrue,
      );
    });

    test('elapsed above grace is expired', () {
      final start = DateTime(2026, 1, 1, 12);
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      window.begin(start);

      expect(
        window.hasExpiredAt(start.add(const Duration(milliseconds: 1501))),
        isTrue,
      );
    });

    test('reset clears active state', () {
      final start = DateTime(2026, 1, 1, 12);
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      window.begin(start);
      window.reset();

      expect(window.isActive, isFalse);
      expect(window.startedAt, isNull);
    });

    test('consume returns the elapsed duration and clears active state', () {
      final start = DateTime(2026, 1, 1, 12);
      final end = start.add(const Duration(milliseconds: 640));
      final window = AnalysisVisibilityGapWindow(
        graceDuration: const Duration(milliseconds: 1500),
      );

      window.begin(start);
      final duration = window.consume(end);

      expect(duration, const Duration(milliseconds: 640));
      expect(window.isActive, isFalse);
      expect(window.startedAt, isNull);
    });
  });
}
