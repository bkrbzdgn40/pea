import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/assessment_models.dart';

class AssessmentSelection {
  const AssessmentSelection({required this.type, this.balanceSide});

  final AssessmentType type;
  final AssessmentSide? balanceSide;
}

final selectedAssessmentProvider = StateProvider<AssessmentSelection?>((ref) {
  return null;
});
