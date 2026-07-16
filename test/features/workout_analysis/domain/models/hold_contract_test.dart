import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';

void main() {
  group('HoldContract', () {
    test('stores an unmodifiable required signal set', () {
      final contract = HoldContract(
        family: HoldAnalysisFamily.plank,
        requiredSignals: const <HoldSignal>{
          HoldSignal.alignment,
          HoldSignal.support,
        },
      );

      expect(contract.family, HoldAnalysisFamily.plank);
      expect(contract.requiredSignals, <HoldSignal>{
        HoldSignal.alignment,
        HoldSignal.support,
      });
      expect(
        () => contract.requiredSignals.add(HoldSignal.extension),
        throwsUnsupportedError,
      );
    });

    test(
      'plankFamily exposes the typed plank family and current hold signals',
      () {
        final contract = HoldContracts.plankFamily;

        expect(contract.family, HoldAnalysisFamily.plank);
        expect(contract.supportsSignal(HoldSignal.alignment), isTrue);
        expect(contract.supportsSignal(HoldSignal.support), isTrue);
        expect(contract.supportsSignal(HoldSignal.extension), isTrue);
        expect(contract.requiredSignals, const <HoldSignal>{
          HoldSignal.alignment,
          HoldSignal.support,
          HoldSignal.extension,
        });
      },
    );
  });
}
