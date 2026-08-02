import 'package:flutter/material.dart';

import '../../../../../app/localization/app_localizations.dart';
import '../../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../application/exercise_definition_metadata.dart';
import '../../../application/saved_workout_plan.dart';
import '../../../application/workout_engine.dart';

class EmptyWorkoutPlan extends StatelessWidget {
  const EmptyWorkoutPlan({super.key, required this.onAddExercise});

  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.playlist_add_rounded,
            size: 48,
            color: Colors.white38,
          ),
          const SizedBox(height: 10),
          Text(
            localizations.emptyPlanTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localizations.emptyPlanBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddExercise,
            icon: const Icon(Icons.add_rounded),
            label: Text(localizations.addExercise),
          ),
        ],
      ),
    );
  }
}

class WorkoutPlanEntryCard extends StatelessWidget {
  const WorkoutPlanEntryCard({
    super.key,
    required this.index,
    required this.entry,
    required this.trackingType,
    required this.onChanged,
    required this.onDuplicate,
    required this.onRemove,
  });

  final int index;
  final SavedWorkoutPlanEntry entry;
  final ExerciseTrackingType trackingType;
  final ValueChanged<SavedWorkoutPlanEntry> onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isHold = trackingType == ExerciseTrackingType.hold;
    final targetValue = isHold
        ? entry.target.holdDuration!.inSeconds
        : entry.target.repetitions!;

    final editors = <Widget>[
      LabeledNumberEditor(
        label: localizations.setCount,
        value: entry.sets,
        minimum: 1,
        maximum: 10,
        step: 1,
        onChanged: (value) => onChanged(entry.copyWith(sets: value)),
      ),
      LabeledNumberEditor(
        label: isHold ? localizations.holdTarget : localizations.repTarget,
        value: targetValue,
        minimum: isHold ? 5 : 1,
        maximum: isHold ? 300 : 100,
        step: isHold ? 5 : 1,
        suffix: isHold
            ? localizations.secondsShort
            : localizations.repetitionsShort,
        onChanged: (value) => onChanged(
          entry.copyWith(
            target: isHold
                ? WorkoutTarget.hold(Duration(seconds: value))
                : WorkoutTarget.repetitions(value),
          ),
        ),
      ),
      LabeledNumberEditor(
        label: localizations.restDuration,
        value: entry.restAfterSet.inSeconds,
        minimum: 0,
        maximum: 300,
        step: 15,
        suffix: localizations.secondsShort,
        onChanged: (value) =>
            onChanged(entry.copyWith(restAfterSet: Duration(seconds: value))),
      ),
    ];

    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stackHeader = constraints.maxWidth < 360 || textScale >= 1.5;
          final inlineEditors = constraints.maxWidth >= 680 && textScale < 1.5;

          final title = Text(
            '${index + 1}. ${localizations.exerciseTitle(entry.exercise.id)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          );
          final actions = <Widget>[
            IconButton(
              key: ValueKey<String>('duplicate-${entry.id}'),
              tooltip: localizations.duplicateExercise,
              onPressed: onDuplicate,
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton(
              key: ValueKey<String>('remove-${entry.id}'),
              tooltip: localizations.removeExercise,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (stackHeader) ...<Widget>[
                Row(
                  children: <Widget>[
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_indicator_rounded),
                      ),
                    ),
                    Expanded(child: title),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
              ] else
                Row(
                  children: <Widget>[
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_indicator_rounded),
                      ),
                    ),
                    Expanded(child: title),
                    ...actions,
                  ],
                ),
              const SizedBox(height: 8),
              if (inlineEditors)
                Row(
                  key: const ValueKey<String>(
                    'workout-plan-entry-inline-editors',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (
                      var editorIndex = 0;
                      editorIndex < editors.length;
                      editorIndex += 1
                    ) ...<Widget>[
                      Expanded(child: editors[editorIndex]),
                      if (editorIndex != editors.length - 1)
                        const SizedBox(width: 10),
                    ],
                  ],
                )
              else
                Column(
                  key: const ValueKey<String>(
                    'workout-plan-entry-stacked-editors',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (
                      var editorIndex = 0;
                      editorIndex < editors.length;
                      editorIndex += 1
                    ) ...<Widget>[
                      editors[editorIndex],
                      if (editorIndex != editors.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class LabeledNumberEditor extends StatelessWidget {
  const LabeledNumberEditor({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.onChanged,
    this.suffix,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final int step;
  final String? suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        PlanNumberEditor(
          value: value,
          minimum: minimum,
          maximum: maximum,
          step: step,
          suffix: suffix,
          semanticLabel: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class PlanNumberEditor extends StatelessWidget {
  const PlanNumberEditor({
    super.key,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.semanticLabel,
    required this.onChanged,
    this.step = 1,
    this.suffix,
  });

  final int value;
  final int minimum;
  final int maximum;
  final int step;
  final String semanticLabel;
  final String? suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      value: '$value${suffix == null ? '' : ' $suffix'}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '$semanticLabel -',
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: value <= minimum
                  ? null
                  : () => onChanged(
                      (value - step).clamp(minimum, maximum).toInt(),
                    ),
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$value${suffix == null ? '' : ' $suffix'}',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '$semanticLabel +',
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: value >= maximum
                  ? null
                  : () => onChanged(
                      (value + step).clamp(minimum, maximum).toInt(),
                    ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
