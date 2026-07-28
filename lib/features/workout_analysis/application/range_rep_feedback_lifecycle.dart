import '../domain/models/range_rep_feedback_code.dart';

/// Keeps transient range-rep feedback readable without allowing it to leak
/// into a later movement phase.
///
/// Live corrective cues receive a short phase-scoped lease. Completed and
/// incomplete-rep cues receive a slightly longer neutral-phase lease. A phase
/// change always invalidates the previous lease before its TTL elapses.
class RangeRepFeedbackLifecycle {
  RangeRepFeedbackLifecycle({
    this.correctiveTtl = const Duration(milliseconds: 1200),
    this.resultTtl = const Duration(milliseconds: 1600),
  }) {
    if (correctiveTtl.isNegative) {
      throw ArgumentError.value(
        correctiveTtl,
        'correctiveTtl',
        'Feedback TTL cannot be negative.',
      );
    }
    if (resultTtl.isNegative) {
      throw ArgumentError.value(
        resultTtl,
        'resultTtl',
        'Feedback TTL cannot be negative.',
      );
    }
  }

  final Duration correctiveTtl;
  final Duration resultTtl;

  RangeRepFeedbackCode? _leasedCode;
  DateTime? _expiresAt;
  String? _leasePhaseKey;

  RangeRepFeedbackCode resolve({
    required DateTime now,
    required String phaseKey,
    required RangeRepFeedbackCode freshCandidate,
    required bool hasFreshCorrectiveCandidate,
    required bool hasLifecycleTransition,
    bool retainFreshCorrective = true,
  }) {
    if (_leasePhaseKey != null && _leasePhaseKey != phaseKey) {
      _clearLease();
    }

    if (hasFreshCorrectiveCandidate) {
      if (retainFreshCorrective) {
        _lease(
          code: freshCandidate,
          now: now,
          phaseKey: phaseKey,
          ttl: correctiveTtl,
        );
      } else {
        _clearLease();
      }
      return freshCandidate;
    }

    if (hasLifecycleTransition) {
      _clearLease();
      if (_isResultCue(freshCandidate)) {
        _lease(
          code: freshCandidate,
          now: now,
          phaseKey: phaseKey,
          ttl: resultTtl,
        );
      }
      return freshCandidate;
    }

    if (_hasActiveLease(now: now, phaseKey: phaseKey)) {
      return _leasedCode!;
    }

    _clearLease();
    return freshCandidate;
  }

  void reset() => _clearLease();

  bool _hasActiveLease({required DateTime now, required String phaseKey}) {
    final expiresAt = _expiresAt;
    return _leasedCode != null &&
        _leasePhaseKey == phaseKey &&
        expiresAt != null &&
        now.isBefore(expiresAt);
  }

  bool _isResultCue(RangeRepFeedbackCode code) {
    return code == RangeRepFeedbackCode.repCompleted ||
        code == RangeRepFeedbackCode.repIncomplete;
  }

  void _lease({
    required RangeRepFeedbackCode code,
    required DateTime now,
    required String phaseKey,
    required Duration ttl,
  }) {
    _leasedCode = code;
    _leasePhaseKey = phaseKey;
    _expiresAt = now.add(ttl);
  }

  void _clearLease() {
    _leasedCode = null;
    _expiresAt = null;
    _leasePhaseKey = null;
  }
}
