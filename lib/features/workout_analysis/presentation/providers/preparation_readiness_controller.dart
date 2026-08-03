import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/setup_readiness_state.dart';
import '../../domain/setup_readiness_state_machine.dart';
import '../models/setup_readiness_view_data.dart';
import 'preparation_camera_controller.dart';

final preparationReadinessClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final preparationReadinessThresholdsProvider =
    Provider<SetupReadinessThresholds>(
      (ref) => SetupReadinessThresholds.defaults,
    );

/// Synchronized raw evidence consumed by the stable readiness controller.
final preparationReadinessEvidenceProvider = Provider.autoDispose
    .family<SetupReadinessEvidence, SetupReadinessRequest>((ref, request) {
      return ref
              .watch(preparationFrameAssessmentProvider(request))
              ?.readinessEvidence ??
          const SetupReadinessEvidence();
    });

/// Stable preparation state shared by the camera overlay and readiness card.
final preparationReadinessStateProvider = StateNotifierProvider.autoDispose
    .family<
      PreparationReadinessController,
      SetupReadinessSnapshot,
      SetupReadinessRequest
    >((ref, request) {
      final controller = PreparationReadinessController(
        stateMachine: SetupReadinessStateMachine(
          thresholds: ref.watch(preparationReadinessThresholdsProvider),
        ),
        clock: ref.watch(preparationReadinessClockProvider),
      );
      final evidenceProvider = preparationReadinessEvidenceProvider(request);
      controller.updateEvidence(ref.read(evidenceProvider));
      ref.listen<SetupReadinessEvidence>(evidenceProvider, (_, next) {
        controller.updateEvidence(next);
      });
      return controller;
    });

class PreparationReadinessController
    extends StateNotifier<SetupReadinessSnapshot> {
  PreparationReadinessController({
    required SetupReadinessStateMachine stateMachine,
    required DateTime Function() clock,
  }) : _stateMachine = stateMachine,
       _clock = clock,
       super(stateMachine.reset(now: clock()));

  final SetupReadinessStateMachine _stateMachine;
  final DateTime Function() _clock;
  Timer? _transitionTimer;

  void updateEvidence(SetupReadinessEvidence evidence) {
    state = _stateMachine.update(evidence: evidence, now: _clock());
    _scheduleNextTransition();
  }

  void advance() {
    state = _stateMachine.tick(now: _clock());
    _scheduleNextTransition();
  }

  void _scheduleNextTransition() {
    _transitionTimer?.cancel();
    final delay = _stateMachine.nextTransitionDelay(now: _clock());
    if (delay == null) {
      return;
    }
    _transitionTimer = Timer(delay, advance);
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }
}
