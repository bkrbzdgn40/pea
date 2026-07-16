import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';

void main() {
  test('preserves the shared radius tokens used by presentation surfaces', () {
    expect(AppRadii.small, 12);
    expect(AppRadii.compact, 14);
    expect(AppRadii.surface, 16);
  });
}
