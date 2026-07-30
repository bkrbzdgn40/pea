import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';

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
  });

  final Duration duration;
  final String planName;
  final String nextExerciseName;
  final int nextSetNumber;
  final Duration tickDuration;

  @override
  State<WorkoutRestScreen> createState() => _WorkoutRestScreenState();
}

class _WorkoutRestScreenState extends State<WorkoutRestScreen> {
  Timer? _timer;
  late int _remainingSeconds;
  bool _isClosing = false;
  bool _allowPop = false;

  int get _totalSeconds => widget.duration.inSeconds.clamp(0, 86400).toInt();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _totalSeconds;
    if (_remainingSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finish(WorkoutRestResult.completed);
      });
      return;
    }
    _timer = Timer.periodic(widget.tickDuration, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _isClosing) {
      return;
    }
    if (_remainingSeconds <= 1) {
      setState(() => _remainingSeconds = 0);
      _finish(WorkoutRestResult.completed);
      return;
    }
    setState(() => _remainingSeconds -= 1);
  }

  void _finish(WorkoutRestResult result) {
    if (!mounted || _isClosing) {
      return;
    }
    _isClosing = true;
    _timer?.cancel();
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final totalSeconds = _totalSeconds;
    final progress = totalSeconds <= 0
        ? 1.0
        : 1 - (_remainingSeconds / totalSeconds);

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
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF10271D), Color(0xFF050907)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.planName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.self_improvement_rounded,
                            color: Colors.greenAccent,
                            size: 54,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            localizations.restScreenTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            localizations.restSetCompleted,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Semantics(
                            liveRegion: true,
                            label: localizations.restCountdown(
                              _formatRestDuration(
                                Duration(seconds: _remainingSeconds),
                              ),
                            ),
                            child: Text(
                              _formatRestDuration(
                                Duration(seconds: _remainingSeconds),
                              ),
                              key: const ValueKey<String>(
                                'planned-rest-countdown',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 72,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0).toDouble(),
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: Colors.white12,
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            localizations.nextPlannedStep(
                              widget.nextExerciseName,
                              widget.nextSetNumber,
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: Colors.amberAccent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                          const Spacer(),
                          OutlinedButton.icon(
                            key: const ValueKey<String>('skip-planned-rest'),
                            onPressed: () => _finish(WorkoutRestResult.skipped),
                            icon: const Icon(Icons.skip_next_rounded),
                            label: Text(localizations.skipRest),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRestDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
