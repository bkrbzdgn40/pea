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

enum _WorkoutPlanBuilderResult { saved }

class _WorkoutPlanSetupScreenState
    extends ConsumerState<WorkoutPlanSetupScreen> {
  String? _selectedPlanId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final savedPlans = ref.watch(savedWorkoutPlansProvider);
    final selectedPlan = _findSelectedPlan(savedPlans.valueOrNull);

    return AppScaffoldShell(
      title: localizations.plannedWorkout,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      body: ListView(
        key: const ValueKey<String>('workout-plan-home-scroll'),
        padding: EdgeInsets.zero,
        children: <Widget>[
          Text(
            localizations.plannedWorkoutBuilderIntro,
            style: const TextStyle(color: Colors.white60, height: 1.35),
          ),
          const SizedBox(height: 12),
          _SavedPlansSection(
            plans: savedPlans,
            selectedPlanId: _selectedPlanId,
            onSelect: (plan) => setState(() => _selectedPlanId = plan.id),
            onDelete: _confirmDeletePlan,
            onNew: () => _openPlanBuilder(),
            onReview: selectedPlan == null
                ? null
                : () => _openSelectedPlanReview(selectedPlan),
          ),
        ],
      ),
    );
  }

  SavedWorkoutPlan? _findSelectedPlan(List<SavedWorkoutPlan>? plans) {
    final selectedPlanId = _selectedPlanId;
    if (selectedPlanId == null || plans == null) {
      return null;
    }
    for (final plan in plans) {
      if (plan.id == selectedPlanId) {
        return plan;
      }
    }
    return null;
  }

  Future<void> _openSelectedPlanReview(SavedWorkoutPlan plan) async {
    final result = await Navigator.push<WorkoutPlanReviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlanReviewScreen(
          plan: plan,
          initiallySaved: true,
          onSaved: () {},
        ),
      ),
    );
    if (!mounted || result != WorkoutPlanReviewResult.edit) {
      return;
    }
    await _openPlanBuilder(plan);
  }

  Future<void> _openPlanBuilder([SavedWorkoutPlan? plan]) async {
    final result = await showModalBottomSheet<_WorkoutPlanBuilderResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => _WorkoutPlanBuilderSheet(initialPlan: plan),
    );
    if (!mounted || result != _WorkoutPlanBuilderResult.saved) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).planSaved)),
    );
  }

  Future<void> _confirmDeletePlan(SavedWorkoutPlan plan) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deletePlan),
        content: Text(localizations.deletePlanConfirmation(plan.name)),
        actions: <Widget>[
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
    if (mounted && _selectedPlanId == plan.id) {
      setState(() => _selectedPlanId = null);
    }
  }
}

class _WorkoutPlanBuilderSheet extends ConsumerStatefulWidget {
  const _WorkoutPlanBuilderSheet({this.initialPlan});

  final SavedWorkoutPlan? initialPlan;

  @override
  ConsumerState<_WorkoutPlanBuilderSheet> createState() =>
      _WorkoutPlanBuilderSheetState();
}

class _WorkoutPlanBuilderSheetState
    extends ConsumerState<_WorkoutPlanBuilderSheet> {
  static const ExerciseCatalog _catalog = ExerciseCatalog();

  late final TextEditingController _nameController;
  final List<SavedWorkoutPlanEntry> _entries = <SavedWorkoutPlanEntry>[];
  String? _planId;
  int _rounds = 1;
  int _entrySequence = 0;
  bool _isSaving = false;
  bool _allowSheetPop = false;
  SavedWorkoutPlan? _loadedPlanBaseline;

  @override
  void initState() {
    super.initState();
    final initialPlan = widget.initialPlan;
    _nameController = TextEditingController(text: initialPlan?.name ?? '');
    if (initialPlan != null) {
      _planId = initialPlan.id;
      _rounds = initialPlan.rounds;
      _entries.addAll(initialPlan.entries);
      _loadedPlanBaseline = initialPlan;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final header = _buildBuilderHeader(localizations);
    final footer = _buildBuilderFooter(localizations);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope<Object?>(
      canPop: _allowSheetPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_requestSheetPop());
        }
      },
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Material(
            key: const ValueKey<String>('workout-plan-builder-sheet'),
            color: const Color(0xFF11171D),
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.initialPlan?.name ?? localizations.newPlan,
                          key: const ValueKey<String>(
                            'workout-plan-builder-title',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>(
                          'close-workout-plan-builder',
                        ),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: _isSaving ? null : _requestSheetPop,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: _entries.isEmpty
                        ? ListView(
                            key: const ValueKey<String>(
                              'workout-plan-builder-scroll',
                            ),
                            padding: EdgeInsets.zero,
                            children: <Widget>[
                              header,
                              const SizedBox(height: 12),
                              _EmptyPlan(onAddExercise: _showExercisePicker),
                              const SizedBox(height: 12),
                              footer,
                            ],
                          )
                        : ReorderableListView.builder(
                            key: const ValueKey<String>(
                              'workout-plan-entry-list',
                            ),
                            buildDefaultDragHandles: false,
                            padding: EdgeInsets.zero,
                            header: header,
                            footer: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: footer,
                            ),
                            itemCount: _entries.length,
                            onReorder: _reorder,
                            proxyDecorator: (child, index, animation) =>
                                Material(
                                  color: Colors.transparent,
                                  elevation: 8,
                                  child: child,
                                ),
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              final definition = _catalog.definitionFor(
                                entry.exercise,
                              );
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
                                  onRemove: () =>
                                      setState(() => _entries.removeAt(index)),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuilderHeader(AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSurfaceCard(
          child: Column(
            children: <Widget>[
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
                children: <Widget>[
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
              if (_hasDraftContent) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
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
          children: <Widget>[
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
            children: <Widget>[
              saveButton,
              const SizedBox(height: 8),
              reviewButton,
            ],
          );
        }
        return Row(
          children: <Widget>[
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

  Future<void> _requestSheetPop() async {
    if (_isSaving || !mounted) {
      return;
    }
    if (!await _confirmDiscardDraft() || !mounted) {
      return;
    }

    setState(() => _allowSheetPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
            actions: <Widget>[
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
        _allowSheetPop = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        Navigator.of(context).pop(_WorkoutPlanBuilderResult.saved);
      }
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
    final plan = _buildPlan();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlanReviewScreen(
          plan: plan,
          onSaved: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _planId = plan.id;
              _loadedPlanBaseline = plan;
            });
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
    required this.selectedPlanId,
    required this.onSelect,
    required this.onDelete,
    required this.onNew,
    required this.onReview,
  });

  final AsyncValue<List<SavedWorkoutPlan>> plans;
  final String? selectedPlanId;
  final ValueChanged<SavedWorkoutPlan> onSelect;
  final ValueChanged<SavedWorkoutPlan> onDelete;
  final VoidCallback onNew;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
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
                key: const ValueKey<String>('new-workout-plan'),
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded),
                label: Text(localizations.newPlan),
              ),
            ],
          ),
          const SizedBox(height: 4),
          plans.when(
            data: (items) {
              if (items.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      localizations.noSavedPlans,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 14),
                    _ReviewSelectedPlanButton(onPressed: null),
                  ],
                );
              }
              return Column(
                key: const ValueKey<String>('saved-workout-plan-list'),
                children: [
                  for (var index = 0; index < items.length; index += 1) ...[
                    _SavedPlanTile(
                      plan: items[index],
                      isSelected: items[index].id == selectedPlanId,
                      onTap: () => onSelect(items[index]),
                      onDelete: () => onDelete(items[index]),
                    ),
                    if (index != items.length - 1) const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 14),
                  _ReviewSelectedPlanButton(onPressed: onReview),
                ],
              );
            },
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(),
                SizedBox(height: 14),
                _ReviewSelectedPlanButton(onPressed: null),
              ],
            ),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.savedPlansLoadFailed,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                const SizedBox(height: 14),
                _ReviewSelectedPlanButton(onPressed: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedPlanTile extends StatelessWidget {
  const _SavedPlanTile({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  final SavedWorkoutPlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final accent = Colors.greenAccent;
    return AnimatedContainer(
      key: ValueKey<String>('saved-plan-card-${plan.id}'),
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? accent.withValues(alpha: 0.58)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('load-plan-${plan.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? accent : Colors.white38,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
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
                      const SizedBox(height: 3),
                      Text(
                        localizations.savedPlanSummary(
                          exercises: plan.entries.length,
                          sets: plan.totalSets,
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('delete-plan-${plan.id}'),
                  tooltip: localizations.deletePlan,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSelectedPlanButton extends StatelessWidget {
  const _ReviewSelectedPlanButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return ElevatedButton.icon(
      key: const ValueKey<String>('review-selected-workout-plan'),
      onPressed: onPressed,
      icon: const Icon(Icons.summarize_rounded),
      label: Text(localizations.reviewPlan),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black,
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
