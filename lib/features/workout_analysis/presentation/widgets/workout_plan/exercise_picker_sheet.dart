import 'package:flutter/material.dart';

import '../../../../../app/localization/app_localizations.dart';
import '../../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../../app/theme/app_design_tokens.dart';
import '../../../../../app/theme/app_semantic_colors.dart';
import '../../../application/exercise_catalog.dart';
import '../../../application/exercise_definition.dart';
import '../../../application/exercise_definition_metadata.dart';

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({super.key});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  static const ExerciseCatalog _catalog = ExerciseCatalog();
  String _query = '';
  ExerciseBodyRegion? _region;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final normalizedQuery = _query.trim().toLowerCase();
    final definitions = _catalog.definitions
        .where((definition) {
          if (!definition.isAnalysisSupported) {
            return false;
          }
          if (_region != null && definition.type.bodyRegion != _region) {
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
      heightFactor: 0.92,
      child: Material(
        color: colors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.foregroundSubtle,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.analysisAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.compact),
                      ),
                      child: Icon(
                        Icons.add_chart_rounded,
                        color: colors.analysisAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            localizations.addExercise,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: AppFontWeights.heavy,
                                ),
                          ),
                          Text(
                            localizations.exerciseResultCount(
                              definitions.length,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.foregroundMuted),
                          ),
                        ],
                      ),
                    ),
                    AppIconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey<String>('plan-exercise-search'),
                  decoration: InputDecoration(
                    hintText: localizations.searchExercisesHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(() => _query = ''),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  key: const ValueKey<String>('plan-exercise-region-scroll'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _RegionFilterChip(
                        label: localizations.allExercises,
                        icon: Icons.apps_rounded,
                        selected: _region == null,
                        onSelected: () => setState(() => _region = null),
                      ),
                      for (final region
                          in ExerciseBodyRegion.values) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        _RegionFilterChip(
                          label: _bodyRegionLabel(localizations, region),
                          icon: _bodyRegionIcon(region),
                          selected: _region == region,
                          onSelected: () => setState(() => _region = region),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (definitions.isEmpty) {
                        return AppSurfaceCard(
                          variant: AppSurfaceVariant.muted,
                          child: Center(
                            child: Text(
                              localizations.noExercisesFound,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.foregroundMuted),
                            ),
                          ),
                        );
                      }
                      final useGrid =
                          constraints.maxWidth >= 700 &&
                          MediaQuery.textScalerOf(context).scale(1) < 1.4;
                      if (useGrid) {
                        return GridView.builder(
                          key: const ValueKey<String>(
                            'plan-exercise-picker-grid',
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.sm,
                                mainAxisSpacing: AppSpacing.sm,
                                mainAxisExtent: 116,
                              ),
                          itemCount: definitions.length,
                          itemBuilder: (context, index) => _ExercisePickerCard(
                            definition: definitions[index],
                          ),
                        );
                      }
                      return ListView.separated(
                        key: const ValueKey<String>(
                          'plan-exercise-picker-list',
                        ),
                        itemCount: definitions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) =>
                            _ExercisePickerCard(definition: definitions[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionFilterChip extends StatelessWidget {
  const _RegionFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.black : colors.foregroundMuted,
      ),
      label: Text(label),
      onSelected: (_) => onSelected(),
      selectedColor: colors.analysisAccent,
      backgroundColor: colors.surfaceStrong,
      side: BorderSide(
        color: selected ? colors.analysisAccent : colors.outline,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.black : colors.foreground,
        fontWeight: AppFontWeights.bold,
      ),
    );
  }
}

class _ExercisePickerCard extends StatelessWidget {
  const _ExercisePickerCard({required this.definition});

  final ExerciseDefinition definition;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final isHold = definition.trackingType == ExerciseTrackingType.hold;
    return AppSurfaceCard(
      variant: AppSurfaceVariant.strong,
      padding: EdgeInsets.zero,
      radius: AppRadii.surface,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('plan-picker-${definition.type.id}'),
          onTap: () => Navigator.pop(context, definition.type),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.analysisAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadii.compact),
                  ),
                  child: Icon(
                    isHold ? Icons.timer_outlined : Icons.repeat_rounded,
                    color: colors.analysisAccent,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        localizations.exerciseTitle(definition.type.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.foreground,
                          fontWeight: AppFontWeights.heavy,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        isHold
                            ? localizations.defaultHoldTarget
                            : localizations.defaultRepTarget,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.foregroundMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppStatusChip(
                  label: _bodyRegionLabel(
                    localizations,
                    definition.type.bodyRegion,
                  ),
                  tone: AppStatusTone.accent,
                  showIcon: false,
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.add_circle_rounded, color: colors.analysisAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _bodyRegionLabel(
  AppLocalizations localizations,
  ExerciseBodyRegion region,
) {
  return switch (region) {
    ExerciseBodyRegion.lowerBody => localizations.lowerBody,
    ExerciseBodyRegion.upperBody => localizations.upperBody,
    ExerciseBodyRegion.core => localizations.core,
    ExerciseBodyRegion.fullBody => localizations.fullBody,
  };
}

IconData _bodyRegionIcon(ExerciseBodyRegion region) {
  return switch (region) {
    ExerciseBodyRegion.lowerBody => Icons.directions_run_rounded,
    ExerciseBodyRegion.upperBody => Icons.fitness_center_rounded,
    ExerciseBodyRegion.core => Icons.accessibility_new_rounded,
    ExerciseBodyRegion.fullBody => Icons.bolt_rounded,
  };
}
