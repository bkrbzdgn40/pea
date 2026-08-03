import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../application/workout_engine.dart';

/// Result returned to live analysis when the planned-workout rest route closes.
enum WorkoutRestResult { completed, skipped }

/// Dedicated between-set rest surface for planned workouts.
class WorkoutRestScreen extends StatefulWidget {
  const WorkoutRestScreen({
    super.key,
    required this.duration,
    required this.planName,
    required this.nextExerciseName,
    required this.nextSetNumber,
    this.tickDuration = const Duration(seconds: 1),
    this.showExerciseCompletionTransition = false,
    this.completedExerciseName,
    this.exerciseCompletionTransitionDuration = const Duration(
      milliseconds: 1500,
    ),
  });

  final Duration duration;
  final String planName;
  final String nextExerciseName;
  final int nextSetNumber;
  final Duration tickDuration;
  final bool showExerciseCompletionTransition;
  final String? completedExerciseName;
  final Duration exerciseCompletionTransitionDuration;

  @override
  State<WorkoutRestScreen> createState() => _WorkoutRestScreenState();
}

class _WorkoutRestScreenState extends State<WorkoutRestScreen> {
  static const int _extensionSeconds = 15;
  static final int _maximumRestSeconds = maxWorkoutPlanRestDuration.inSeconds;
  Timer? _timer;
  Timer? _exerciseCompletionTimer;
  late int _remainingSeconds;
  late int _activeDurationSeconds;
  late bool _showExerciseCompletionTransition;
  bool _timerElapsed = false;
  bool _isClosing = false;
  bool _allowPop = false;

  int get _totalSeconds =>
      widget.duration.inSeconds.clamp(0, _maximumRestSeconds).toInt();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _totalSeconds;
    _activeDurationSeconds = _totalSeconds;
    _showExerciseCompletionTransition = widget.showExerciseCompletionTransition;
    if (_showExerciseCompletionTransition) {
      _exerciseCompletionTimer = Timer(
        widget.exerciseCompletionTransitionDuration,
        _completeExerciseTransition,
      );
      return;
    }
    _startRestFlow();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _exerciseCompletionTimer?.cancel();
    super.dispose();
  }

  void _completeExerciseTransition() {
    if (!mounted || _isClosing || !_showExerciseCompletionTransition) {
      return;
    }
    setState(() => _showExerciseCompletionTransition = false);
    _startRestFlow();
  }

  void _startRestFlow() {
    if (_remainingSeconds <= 0) {
      _timerElapsed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finish(WorkoutRestResult.completed);
      });
      return;
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.tickDuration, (_) => _tick());
  }

  void _tick() {
    if (!mounted || _isClosing || _timerElapsed) {
      return;
    }
    if (_remainingSeconds <= 1) {
      _timer?.cancel();
      setState(() {
        _remainingSeconds = 0;
        _timerElapsed = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finish(WorkoutRestResult.completed);
      });
      return;
    }
    setState(() => _remainingSeconds -= 1);
  }

  void _addRestTime() {
    if (_isClosing) {
      return;
    }
    if (_remainingSeconds >= _maximumRestSeconds) {
      return;
    }
    setState(() {
      final nextRemaining = (_remainingSeconds + _extensionSeconds)
          .clamp(0, _maximumRestSeconds)
          .toInt();
      final addedSeconds = nextRemaining - _remainingSeconds;
      _remainingSeconds = nextRemaining;
      _activeDurationSeconds = (_activeDurationSeconds + addedSeconds)
          .clamp(1, _maximumRestSeconds)
          .toInt();
      _timerElapsed = false;
    });
    _startTimer();
  }

  void _finish(WorkoutRestResult result) {
    if (!mounted || _isClosing) {
      return;
    }
    _isClosing = true;
    _timer?.cancel();
    _exerciseCompletionTimer?.cancel();
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _activeDurationSeconds <= 0
        ? 1.0
        : 1 - (_remainingSeconds / _activeDurationSeconds);

    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _finish(WorkoutRestResult.skipped);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07110D),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF153226), Color(0xFF050907)],
            ),
          ),
          child: SafeArea(
            child: _showExerciseCompletionTransition
                ? _ExerciseCompletionTransitionView(
                    completedExerciseName: widget.completedExerciseName,
                    nextExerciseName: widget.nextExerciseName,
                    nextSetNumber: widget.nextSetNumber,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final layout = AppLayout.of(
                        context,
                        constraints: constraints,
                      );
                      final useSplitLayout =
                          layout.isLandscape &&
                          constraints.maxWidth >= 700 &&
                          !layout.hasLargeText;
                      final countdown = _RestCountdownPanel(
                        planName: widget.planName,
                        remainingSeconds: _remainingSeconds,
                        progress: progress.clamp(0.0, 1.0).toDouble(),
                        timerElapsed: _timerElapsed,
                        compact: layout.isCompact,
                      );
                      final details = _RestDetailsPanel(
                        nextExerciseName: widget.nextExerciseName,
                        nextSetNumber: widget.nextSetNumber,
                        extensionSeconds: _extensionSeconds,
                        canAddTime: _remainingSeconds < _maximumRestSeconds,
                        onAddTime: _addRestTime,
                        onReady: () => _finish(WorkoutRestResult.completed),
                      );

                      return Padding(
                        padding: layout.pagePadding,
                        child: useSplitLayout
                            ? Row(
                                key: const ValueKey<String>(
                                  'planned-rest-split-layout',
                                ),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(
                                    flex: 5,
                                    child: LayoutBuilder(
                                      builder: (context, paneConstraints) =>
                                          SingleChildScrollView(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minHeight:
                                                    paneConstraints.maxHeight,
                                              ),
                                              child: countdown,
                                            ),
                                          ),
                                    ),
                                  ),
                                  SizedBox(width: layout.panelGap),
                                  SizedBox(
                                    width: (constraints.maxWidth * 0.36)
                                        .clamp(300.0, 380.0)
                                        .toDouble(),
                                    child: SingleChildScrollView(
                                      child: details,
                                    ),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                key: const ValueKey<String>(
                                  'planned-rest-stacked-layout',
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    countdown,
                                    SizedBox(height: layout.sectionGap),
                                    details,
                                  ],
                                ),
                              ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseCompletionTransitionView extends StatelessWidget {
  const _ExerciseCompletionTransitionView({
    required this.completedExerciseName,
    required this.nextExerciseName,
    required this.nextSetNumber,
  });

  final String? completedExerciseName;
  final String nextExerciseName;
  final int nextSetNumber;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final completedName = completedExerciseName?.trim();
    final message = completedName == null || completedName.isEmpty
        ? localizations.restSetCompleted
        : localizations.plannedExerciseCompletedMessage(completedName);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppLayout.of(context, constraints: constraints);
        return SingleChildScrollView(
          key: const ValueKey<String>('planned-exercise-completion-transition'),
          padding: layout.pagePadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - layout.pagePadding.vertical)
                  .clamp(0.0, double.infinity)
                  .toDouble(),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: layout.isCompact ? 88 : 104,
                      height: layout.isCompact ? 88 : 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.48),
                          width: 2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.22),
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.success,
                        size: 58,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      localizations.plannedExerciseCompleted,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.primaryForeground,
                            fontWeight: AppFontWeights.heavy,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryForeground,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.analysisAccent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: AppColors.analysisAccent.withValues(
                            alpha: 0.30,
                          ),
                        ),
                      ),
                      child: Text(
                        localizations.nextPlannedStep(
                          nextExerciseName,
                          nextSetNumber,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.secondaryForeground,
                          fontWeight: AppFontWeights.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RestCountdownPanel extends StatelessWidget {
  const _RestCountdownPanel({
    required this.planName,
    required this.remainingSeconds,
    required this.progress,
    required this.timerElapsed,
    required this.compact,
  });

  static const Color _accent = Color(0xFF61E6BE);

  final String planName;
  final int remainingSeconds;
  final double progress;
  final bool timerElapsed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final countdown = _formatRestDuration(Duration(seconds: remainingSeconds));

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1712).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accent.withValues(alpha: 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            planName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 16 : 24),
          Icon(
            timerElapsed
                ? Icons.check_circle_rounded
                : Icons.self_improvement_rounded,
            color: _accent,
            size: compact ? 42 : 54,
          ),
          const SizedBox(height: 12),
          Text(
            timerElapsed
                ? localizations.restReadyTitle
                : localizations.restScreenTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 24 : 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            timerElapsed
                ? localizations.restReadyMessage
                : localizations.restSetCompleted,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: compact ? 18 : 28),
          Semantics(
            liveRegion: true,
            label: localizations.restCountdown(countdown),
            child: Text(
              countdown,
              key: const ValueKey<String>('planned-rest-countdown'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _accent,
                fontSize: compact ? 58 : 76,
                height: 1,
                fontWeight: FontWeight.w900,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white12,
            color: _accent,
          ),
        ],
      ),
    );
  }
}

class _RestDetailsPanel extends StatelessWidget {
  const _RestDetailsPanel({
    required this.nextExerciseName,
    required this.nextSetNumber,
    required this.extensionSeconds,
    required this.canAddTime,
    required this.onAddTime,
    required this.onReady,
  });

  static const Color _accent = Color(0xFF61E6BE);

  final String nextExerciseName;
  final int nextSetNumber;
  final int extensionSeconds;
  final bool canAddTime;
  final VoidCallback onAddTime;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111D17),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.next_plan_rounded, color: _accent, size: 28),
              const SizedBox(height: 12),
              Text(
                localizations.nextPlannedStep(nextExerciseName, nextSetNumber),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Colors.amberAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      localizations.restTipTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations.restTipBody,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackActions = constraints.maxWidth < 330 || textScale >= 1.5;
            final addButton = OutlinedButton.icon(
              key: const ValueKey<String>('add-planned-rest-time'),
              onPressed: canAddTime ? onAddTime : null,
              icon: const Icon(Icons.add_alarm_rounded),
              label: Text(localizations.addRestTime(extensionSeconds)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                minimumSize: const Size.fromHeight(52),
              ),
            );
            final readyButton = FilledButton.icon(
              key: const ValueKey<String>('complete-planned-rest'),
              onPressed: onReady,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(localizations.readyForNextSet),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _accent,
                foregroundColor: Colors.black,
              ),
            );

            if (stackActions) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  readyButton,
                  const SizedBox(height: 10),
                  addButton,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: addButton),
                const SizedBox(width: 10),
                Expanded(child: readyButton),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _formatRestDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
