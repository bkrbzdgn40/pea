import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_definition_metadata.dart';
import '../../application/saved_workout_plan.dart';
import '../../application/workout_engine.dart';
import '../../domain/models/exercise_type.dart';
import '../providers/saved_workout_plans_provider.dart';
import 'workout_plan_review_screen.dart';

class WorkoutPlanSetupScreen extends ConsumerStatefulWidget {
  const WorkoutPlanSetupScreen({super.key});

  @override
  ConsumerState<WorkoutPlanSetupScreen> createState() =>
      _WorkoutPlanSetupScreenState();
}

class _WorkoutPlanSetupScreenState
    extends ConsumerState<WorkoutPlanSetupScreen> {
  static const ExerciseCatalog _catalog = ExerciseCatalog();

  final TextEditingController _nameController = TextEditingController();
  final List<SavedWorkoutPlanEntry> _entries = <SavedWorkoutPlanEntry>[];
  String? _planId;
  int _rounds = 1;
  int _entrySequence = 0;
  bool _isSaving = false;
  bool _allowRoutePop = false;
  SavedWorkoutPlan? _loadedPlanBaseline;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final savedPlans = ref.watch(savedWorkoutPlansProvider);
    final header = _buildBuilderHeader(localizations, savedPlans);
    final footer = _buildBuilderFooter(localizations);

    return PopScope<Object?>(
      canPop: _allowRoutePop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_requestRoutePop());
        }
      },
      child: AppScaffoldShell(
        title: localizations.plannedWorkout,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        body: _entries.isEmpty
            ? ListView(
                key: const ValueKey<String>('workout-plan-builder-scroll'),
                padding: EdgeInsets.zero,
                children: [
                  header,
                  const SizedBox(height: 12),
                  _EmptyPlan(onAddExercise: _showExercisePicker),
                  const SizedBox(height: 12),
                  footer,
                ],
              )
            : ReorderableListView.builder(
                key: const ValueKey<String>('workout-plan-entry-list'),
                buildDefaultDragHandles: false,
                padding: EdgeInsets.zero,
                header: header,
                footer: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: footer,
                ),
                itemCount: _entries.length,
                onReorder: _reorder,
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent,
                  elevation: 8,
                  child: child,
                ),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final definition = _catalog.definitionFor(entry.exercise);
                  return Padding(
                    key: ValueKey<String>(entry.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WorkoutPlanEntryCard(
                      index: index,
                      entry: entry,
                      trackingType: definition.trackingType,
                      onChanged: (updated) {
                        setState(() => _entries[index] = updated);
                      },
                      onDuplicate: () => _duplicateEntry(index),
                      onRemove: () => setState(() => _entries.removeAt(index)),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildBuilderHeader(
    AppLocalizations localizations,
    AsyncValue<List<SavedWorkoutPlan>> savedPlans,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.plannedWorkoutBuilderIntro,
          style: const TextStyle(color: Colors.white60, height: 1.35),
        ),
        const SizedBox(height: 12),
        _SavedPlansSection(
          plans: savedPlans,
          onLoad: (plan) => _loadPlan(plan),
          onDelete: _confirmDeletePlan,
          onNew: _requestNewPlan,
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: Column(
            children: [
              TextField(
                key: const ValueKey<String>('workout-plan-name-field'),
                controller: _nameController,
                maxLength: 60,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: localizations.planName,
                  hintText: localizations.planNameHint,
                  counterText: '',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      localizations.roundCount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 155,
                    child: _PlanNumberEditor(
                      value: _rounds,
                      minimum: 1,
                      maximum: 10,
                      semanticLabel: localizations.roundCount,
                      onChanged: (value) => setState(() => _rounds = value),
                    ),
                  ),
                ],
              ),
              if (_hasDraftContent) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _hasUnsavedChanges
                          ? Icons.edit_note_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: _hasUnsavedChanges
                          ? Colors.orangeAccent
                          : Colors.greenAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _hasUnsavedChanges
                            ? localizations.unsavedPlanChanges
                            : localizations.planUpToDate,
                        style: TextStyle(
                          color: _hasUnsavedChanges
                              ? Colors.orangeAccent
                              : Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                localizations.exerciseOrder,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey<String>('add-plan-exercise'),
              onPressed: _showExercisePicker,
              icon: const Icon(Icons.add_rounded),
              label: Text(localizations.addExercise),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBuilderFooter(AppLocalizations localizations) {
    final saveButton = OutlinedButton.icon(
      key: const ValueKey<String>('save-workout-plan'),
      onPressed: _canSave ? _savePlan : null,
      icon: _isSaving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(
        _planId == null
            ? localizations.savePlan
            : localizations.savePlanChanges,
      ),
    );
    final reviewButton = ElevatedButton.icon(
      key: const ValueKey<String>('review-workout-plan'),
      onPressed: _canContinue ? _openReview : null,
      icon: const Icon(Icons.summarize_rounded),
      label: Text(localizations.reviewPlan),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackActions = constraints.maxWidth < 420 || textScale > 1.3;
        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [saveButton, const SizedBox(height: 8), reviewButton],
          );
        }
        return Row(
          children: [
            Expanded(child: saveButton),
            const SizedBox(width: 10),
            Expanded(child: reviewButton),
          ],
        );
      },
    );
  }

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty && _entries.isNotEmpty;

  bool get _hasDraftContent =>
      _nameController.text.trim().isNotEmpty ||
      _entries.isNotEmpty ||
      _rounds != 1;

  bool get _hasUnsavedChanges {
    final baseline = _loadedPlanBaseline;
    if (baseline == null) {
      return _hasDraftContent;
    }
    return !_matchesCurrentDraft(baseline);
  }

  bool get _canSave => _canContinue && _hasUnsavedChanges && !_isSaving;

  SavedWorkoutPlan _buildPlan() {
    final now = DateTime.now();
    return SavedWorkoutPlan(
      id: _planId ?? 'plan-${now.microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      rounds: _rounds,
      entries: _entries,
      updatedAt: now,
    );
  }

  bool _matchesCurrentDraft(SavedWorkoutPlan plan) {
    if (_planId != plan.id ||
        _nameController.text.trim() != plan.name ||
        _rounds != plan.rounds ||
        _entries.length != plan.entries.length) {
      return false;
    }
    for (var index = 0; index < _entries.length; index += 1) {
      final current = _entries[index];
      final saved = plan.entries[index];
      if (current.id != saved.id ||
          current.exercise != saved.exercise ||
          current.sets != saved.sets ||
          current.restAfterSet != saved.restAfterSet ||
          current.target.type != saved.target.type ||
          current.target.repetitions != saved.target.repetitions ||
          current.target.holdDuration != saved.target.holdDuration) {
        return false;
      }
    }
    return true;
  }

  void _resetDraftState() {
    _planId = null;
    _loadedPlanBaseline = null;
    _nameController.clear();
    _rounds = 1;
    _entries.clear();
  }

  Future<void> _requestRoutePop() async {
    if (_isSaving || !mounted) {
      return;
    }
    if (!await _confirmDiscardDraft() || !mounted) {
      return;
    }

    setState(() => _allowRoutePop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _requestNewPlan() async {
    if (!await _confirmDiscardDraft() || !mounted) {
      return;
    }
    setState(_resetDraftState);
  }

  Future<void> _loadPlan(SavedWorkoutPlan plan) async {
    if (_planId == plan.id && !_hasUnsavedChanges) {
      return;
    }
    if (!await _confirmDiscardDraft()) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _planId = plan.id;
      _loadedPlanBaseline = plan;
      _nameController.text = plan.name;
      _rounds = plan.rounds;
      _entries
        ..clear()
        ..addAll(plan.entries);
    });
  }

  Future<bool> _confirmDiscardDraft() async {
    if (!_hasUnsavedChanges) {
      return true;
    }
    final localizations = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(localizations.discardPlanChangesTitle),
            content: Text(localizations.discardPlanChangesBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(localizations.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(localizations.discardChanges),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _confirmDeletePlan(SavedWorkoutPlan plan) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deletePlan),
        content: Text(localizations.deletePlanConfirmation(plan.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(savedWorkoutPlansProvider.notifier).delete(plan.id);
    if (_planId == plan.id && mounted) {
      setState(_resetDraftState);
    }
  }

  Future<void> _savePlan() async {
    if (!_canSave) {
      return;
    }
    setState(() => _isSaving = true);
    final plan = _buildPlan();
    try {
      await ref.read(savedWorkoutPlansProvider.notifier).save(plan);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _resetDraftState();
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).planSaved)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).planSaveFailed)),
      );
    }
  }

  void _openReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlanReviewScreen(
          plan: _buildPlan(),
          onSaved: () {
            if (mounted) {
              setState(_resetDraftState);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showExercisePicker() async {
    final exercise = await showModalBottomSheet<ExerciseType>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ExercisePickerSheet(),
    );
    if (exercise == null || !mounted) {
      return;
    }

    final definition = _catalog.definitionFor(exercise);
    final target = definition.trackingType == ExerciseTrackingType.hold
        ? const WorkoutTarget.hold(Duration(seconds: 30))
        : const WorkoutTarget.repetitions(10);
    setState(() {
      _entries.add(
        SavedWorkoutPlanEntry(
          id: _nextEntryId(),
          exercise: exercise,
          sets: 1,
          target: target,
          restAfterSet: const Duration(seconds: 15),
        ),
      );
    });
  }

  String _nextEntryId() {
    _entrySequence += 1;
    return 'entry-${DateTime.now().microsecondsSinceEpoch}-$_entrySequence';
  }

  void _duplicateEntry(int index) {
    final source = _entries[index];
    setState(() {
      _entries.insert(index + 1, source.copyWith(id: _nextEntryId()));
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final entry = _entries.removeAt(oldIndex);
      _entries.insert(newIndex, entry);
    });
  }
}

class _SavedPlansSection extends StatelessWidget {
  const _SavedPlansSection({
    required this.plans,
    required this.onLoad,
    required this.onDelete,
    required this.onNew,
  });

  final AsyncValue<List<SavedWorkoutPlan>> plans;
  final ValueChanged<SavedWorkoutPlan> onLoad;
  final ValueChanged<SavedWorkoutPlan> onDelete;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.savedPlans,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded),
                label: Text(localizations.newPlan),
              ),
            ],
          ),
          plans.when(
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  localizations.noSavedPlans,
                  style: const TextStyle(color: Colors.white54),
                );
              }
              return SizedBox(
                height: 66,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final plan = items[index];
                    return Container(
                      width: 155,
                      padding: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              key: ValueKey<String>('load-plan-${plan.id}'),
                              onTap: () => onLoad(plan),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    localizations.savedPlanSummary(
                                      exercises: plan.entries.length,
                                      sets: plan.totalSets,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: localizations.deletePlan,
                            onPressed: () => onDelete(plan),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(
              localizations.savedPlansLoadFailed,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({required this.onAddExercise});

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

class _WorkoutPlanEntryCard extends StatelessWidget {
  const _WorkoutPlanEntryCard({
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

    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator_rounded),
                ),
              ),
              Expanded(
                child: Text(
                  '${index + 1}. ${localizations.exerciseTitle(entry.exercise.id)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _LabeledNumberEditor(
                label: localizations.setCount,
                value: entry.sets,
                minimum: 1,
                maximum: 10,
                step: 1,
                onChanged: (value) => onChanged(entry.copyWith(sets: value)),
              ),
              _LabeledNumberEditor(
                label: isHold
                    ? localizations.holdTarget
                    : localizations.repTarget,
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
              _LabeledNumberEditor(
                label: localizations.restDuration,
                value: entry.restAfterSet.inSeconds,
                minimum: 0,
                maximum: 300,
                step: 15,
                suffix: localizations.secondsShort,
                onChanged: (value) => onChanged(
                  entry.copyWith(restAfterSet: Duration(seconds: value)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabeledNumberEditor extends StatelessWidget {
  const _LabeledNumberEditor({
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
    return SizedBox(
      width: 155,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          _PlanNumberEditor(
            value: value,
            minimum: minimum,
            maximum: maximum,
            step: step,
            suffix: suffix,
            semanticLabel: label,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PlanNumberEditor extends StatelessWidget {
  const _PlanNumberEditor({
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
              constraints: const BoxConstraints.tightFor(width: 40, height: 46),
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
              constraints: const BoxConstraints.tightFor(width: 40, height: 46),
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

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  static const ExerciseCatalog _catalog = ExerciseCatalog();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final normalizedQuery = _query.trim().toLowerCase();
    final definitions = _catalog.definitions
        .where((definition) {
          if (!definition.isAnalysisSupported) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          final title = localizations
              .exerciseTitle(definition.type.id)
              .toLowerCase();
          return title.contains(normalizedQuery) ||
              definition.type.title.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localizations.addExercise,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('plan-exercise-search'),
              decoration: InputDecoration(
                hintText: localizations.searchExercisesHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: definitions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final definition = definitions[index];
                  return ListTile(
                    key: ValueKey<String>('plan-picker-${definition.type.id}'),
                    leading: Icon(
                      definition.trackingType == ExerciseTrackingType.hold
                          ? Icons.timer_outlined
                          : Icons.repeat_rounded,
                    ),
                    title: Text(
                      localizations.exerciseTitle(definition.type.id),
                    ),
                    subtitle: Text(
                      definition.trackingType == ExerciseTrackingType.hold
                          ? localizations.defaultHoldTarget
                          : localizations.defaultRepTarget,
                    ),
                    trailing: const Icon(Icons.add_circle_outline_rounded),
                    onTap: () => Navigator.pop(context, definition.type),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
