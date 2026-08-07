import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_button.dart';
import '../../../../app/presentation/widgets/app_feedback_banner.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/user_workout_goal.dart';
import '../../domain/models/workout_goal_template.dart';

class GoalEditorSheet extends StatefulWidget {
  const GoalEditorSheet({
    super.key,
    required this.template,
    required this.initialValue,
    this.isEditing = false,
    this.replacesActiveGoal = false,
  });

  final WorkoutGoalTemplate template;
  final double initialValue;
  final bool isEditing;
  final bool replacesActiveGoal;

  @override
  State<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<GoalEditorSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatValue(widget.initialValue),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isEditing
                ? localizations.editGoal
                : localizations.createGoal,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.userGoalDescription(
              widget.template.type.storageValue,
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.foregroundMuted),
          ),
          if (widget.replacesActiveGoal) ...[
            const SizedBox(height: AppSpacing.md),
            AppFeedbackBanner(
              message: localizations.startingGoalPausesCurrent,
              tone: AppStatusTone.caution,
              icon: Icons.swap_horiz_rounded,
              liveRegion: false,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            localizations.quickGoalValues,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.foregroundMuted,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _presetValues(widget.template)
                .map(
                  (value) => ChoiceChip(
                    label: Text(_formatValue(value)),
                    selected: _controller.text == _formatValue(value),
                    onSelected: (_) => _selectPreset(value),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('goal-target-field'),
            controller: _controller,
            autofocus: false,
            keyboardType: TextInputType.numberWithOptions(
              decimal: !widget.template.requiresWholeNumber,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: localizations.goalTargetLabel,
              suffixText: localizations.userGoalUnit(
                widget.template.type.storageValue,
              ),
              helperText: localizations.goalTargetRange(
                _formatValue(widget.template.minimumTarget),
                _formatValue(widget.template.maximumTarget),
              ),
              errorText: _errorText,
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              } else {
                setState(() {});
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: widget.isEditing
                ? localizations.saveChanges
                : localizations.startGoal,
            icon: widget.isEditing ? Icons.check_rounded : Icons.flag_rounded,
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  void _selectPreset(double value) {
    setState(() {
      _controller.text = _formatValue(value);
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _errorText = null;
    });
  }

  void _submit() {
    final normalized = _controller.text.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || !widget.template.accepts(value)) {
      setState(() {
        _errorText = AppLocalizations.of(context).goalTargetInvalid;
      });
      return;
    }

    Navigator.of(context).pop(value);
  }
}

String _formatValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

List<double> _presetValues(WorkoutGoalTemplate template) {
  return switch (template.type) {
    WorkoutGoalType.weeklySessions => const <double>[3, 5, 7],
    WorkoutGoalType.weeklyReps => const <double>[100, 200, 300],
    WorkoutGoalType.averageScore => const <double>[80, 85, 90],
  };
}
