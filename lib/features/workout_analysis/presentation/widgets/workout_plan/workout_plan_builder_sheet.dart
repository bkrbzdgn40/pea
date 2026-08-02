import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/layout/app_layout.dart';
import '../../../../../app/localization/app_localizations.dart';
import '../../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../application/exercise_catalog.dart';
import '../../../application/exercise_definition_metadata.dart';
import '../../../application/saved_workout_plan.dart';
import '../../../application/workout_engine.dart';
import '../../../domain/models/exercise_type.dart';
import '../../providers/saved_workout_plans_provider.dart';
import '../../screens/workout_plan_review_screen.dart';
import 'exercise_picker_sheet.dart';
import 'workout_plan_builder_widgets.dart';

enum WorkoutPlanBuilderResult { saved }

class WorkoutPlanBuilderSheet extends ConsumerStatefulWidget {
  const WorkoutPlanBuilderSheet({super.key, this.initialPlan});

  final SavedWorkoutPlan? initialPlan;

  @override
  ConsumerState<WorkoutPlanBuilderSheet> createState() =>
      _WorkoutPlanBuilderSheetState();
}

class _WorkoutPlanBuilderSheetState
    extends ConsumerState<WorkoutPlanBuilderSheet> {
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope<Object?>(
      canPop: _allowSheetPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_requestSheetPop());
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);
          final useSplitLayout =
              layout.isLandscape &&
              constraints.maxWidth >= 720 &&
              !layout.hasLargeText;
          final sheetRadius = useSplitLayout
              ? BorderRadius.circular(24)
              : const BorderRadius.vertical(top: Radius.circular(28));

          return Align(
            alignment: useSplitLayout
                ? Alignment.center
                : Alignment.bottomCenter,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: FractionallySizedBox(
                key: ValueKey<String>(
                  useSplitLayout
                      ? 'workout-plan-builder-split-layout'
                      : 'workout-plan-builder-stacked-layout',
                ),
                widthFactor: useSplitLayout ? 0.96 : 1,
                heightFactor: useSplitLayout ? 0.96 : 0.94,
                child: Material(
                  key: const ValueKey<String>('workout-plan-builder-sheet'),
                  color: const Color(0xFF11171D),
                  clipBehavior: Clip.antiAlias,
                  borderRadius: sheetRadius,
                  child: Column(
                    children: <Widget>[
                      if (!useSplitLayout) ...<Widget>[
                        const SizedBox(height: 10),
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          useSplitLayout ? 14 : 10,
                          8,
                          8,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget.initialPlan?.name ??
                                    localizations.newPlan,
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
                        child: _buildBuilderContent(
                          localizations,
                          constraints: constraints,
                          layout: layout,
                          useSplitLayout: useSplitLayout,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBuilderContent(
    AppLocalizations localizations, {
    required BoxConstraints constraints,
    required AppLayout layout,
    required bool useSplitLayout,
  }) {
    if (!useSplitLayout) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: _buildEntryList(
          localizations,
          includeSettings: true,
          includeFooter: true,
        ),
      );
    }

    final settingsWidth = (constraints.maxWidth * 0.34)
        .clamp(300.0, 370.0)
        .toDouble();
    return Padding(
      padding: layout.pagePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: settingsWidth,
            child: SingleChildScrollView(
              key: const ValueKey<String>('workout-plan-settings-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildPlanSettingsCard(localizations),
                  SizedBox(height: layout.sectionGap),
                  _buildBuilderFooter(localizations),
                ],
              ),
            ),
          ),
          SizedBox(width: layout.panelGap),
          Expanded(
            child: _buildEntryList(
              localizations,
              includeSettings: false,
              includeFooter: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(
    AppLocalizations localizations, {
    required bool includeSettings,
    required bool includeFooter,
  }) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (includeSettings) ...<Widget>[
          _buildPlanSettingsCard(localizations),
          const SizedBox(height: 12),
        ],
        _buildExerciseSectionHeader(localizations),
      ],
    );

    if (_entries.isEmpty) {
      return ListView(
        key: const ValueKey<String>('workout-plan-builder-scroll'),
        padding: EdgeInsets.zero,
        children: <Widget>[
          header,
          const SizedBox(height: 12),
          EmptyWorkoutPlan(onAddExercise: _showExercisePicker),
          if (includeFooter) ...<Widget>[
            const SizedBox(height: 12),
            _buildBuilderFooter(localizations),
          ],
        ],
      );
    }

    return ReorderableListView.builder(
      key: const ValueKey<String>('workout-plan-entry-list'),
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      header: header,
      footer: includeFooter
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildBuilderFooter(localizations),
            )
          : null,
      itemCount: _entries.length,
      onReorder: _reorder,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, elevation: 8, child: child),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final definition = _catalog.definitionFor(entry.exercise);
        return Padding(
          key: ValueKey<String>(entry.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: WorkoutPlanEntryCard(
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
    );
  }

  Widget _buildPlanSettingsCard(AppLocalizations localizations) {
    return AppSurfaceCard(
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
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stackRounds =
                  constraints.maxWidth < 300 || textScale >= 1.5;
              final editor = PlanNumberEditor(
                value: _rounds,
                minimum: 1,
                maximum: 10,
                semanticLabel: localizations.roundCount,
                onChanged: (value) => setState(() => _rounds = value),
              );
              if (stackRounds) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      localizations.roundCount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    editor,
                  ],
                );
              }
              return Row(
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
                  SizedBox(width: 155, child: editor),
                ],
              );
            },
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
    );
  }

  Widget _buildExerciseSectionHeader(AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
        Navigator.of(context).pop(WorkoutPlanBuilderResult.saved);
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
      builder: (_) => const ExercisePickerSheet(),
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
