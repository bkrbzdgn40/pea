import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/range_rep_outcome_view_data.dart';
import 'active_analysis_exercise_provider.dart';

final liveRangeRepOutcomeDisplayDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 2800),
);

final liveRangeRepOutcomeProvider =
    StateNotifierProvider.autoDispose<
      LiveRangeRepOutcomeController,
      RangeRepOutcomeViewData?
    >((ref) {
      ref.watch(activeAnalysisExerciseProvider);
      return LiveRangeRepOutcomeController(
        displayDuration: ref.watch(liveRangeRepOutcomeDisplayDurationProvider),
      );
    });

class LiveRangeRepOutcomeController
    extends StateNotifier<RangeRepOutcomeViewData?> {
  LiveRangeRepOutcomeController({required Duration displayDuration})
    : _displayDuration = displayDuration,
      super(null);

  final Duration _displayDuration;
  Timer? _dismissTimer;
  int? _lastPublishedRepIndex;

  bool show(RangeRepOutcomeViewData outcome) {
    if (_lastPublishedRepIndex == outcome.repIndex) {
      return false;
    }

    _lastPublishedRepIndex = outcome.repIndex;
    _dismissTimer?.cancel();
    state = outcome;
    _dismissTimer = Timer(_displayDuration, dismiss);
    return true;
  }

  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    state = null;
  }

  void reset() {
    dismiss();
    _lastPublishedRepIndex = null;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}
