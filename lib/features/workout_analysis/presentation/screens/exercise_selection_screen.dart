import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_definition.dart';
import '../../application/exercise_definition_metadata.dart';
import '../../domain/models/exercise_type.dart';
import '../data/exercise_guide_catalog.dart';
import '../data/localized_exercise_guide_content.dart';
import '../models/exercise_guide_content.dart';
import '../providers/recent_exercises_provider.dart';
import '../providers/selected_exercise_provider.dart';
import 'camera_permission_screen.dart';
import 'guide_screen.dart';

class ExerciseSelectionScreen extends ConsumerStatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  ConsumerState<ExerciseSelectionScreen> createState() =>
      _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState
    extends ConsumerState<ExerciseSelectionScreen> {
  static const _catalog = ExerciseCatalog();
  static const _guideCatalog = ExerciseGuideCatalog();

  final TextEditingController _searchController = TextEditingController();
  ExerciseBodyRegion? _selectedRegion;
  String _query = '';
  bool _isCategoryExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final definitions = _filteredDefinitions(localizations);
    final recentExercises =
        ref.watch(recentExercisesProvider).valueOrNull ??
        const <ExerciseType>[];
    final showRecent =
        _query.isEmpty && _selectedRegion == null && recentExercises.isNotEmpty;
    final analysisReadyCount = _catalog.definitions
        .where((definition) => definition.isAnalysisSupported)
        .length;
    final resultsPadding = AppLayout.of(context).pagePadding.copyWith(top: 2);

    return AppScaffoldShell(
      title: localizations.selectExercise,
      currentPage: AppDestination.exerciseSelection,
      padding: EdgeInsets.zero,
      body: ListView(
        key: const PageStorageKey<String>('exercise-selection-results'),
        padding: EdgeInsets.zero,
        children: [
          _ExerciseDiscoveryHeader(
            searchController: _searchController,
            selectedRegion: _selectedRegion,
            isCategoryExpanded: _isCategoryExpanded,
            analysisReadyCount: analysisReadyCount,
            guideCount: _catalog.definitions.length,
            onQueryChanged: (query) {
              setState(() => _query = query.trim().toLowerCase());
            },
            onClearSearch: _clearSearch,
            onToggleCategory: () {
              setState(() => _isCategoryExpanded = !_isCategoryExpanded);
            },
            onRegionSelected: (region) {
              setState(() {
                _selectedRegion = region;
                _isCategoryExpanded = false;
              });
            },
          ),
          Padding(
            padding: resultsPadding,
            child: definitions.isEmpty
                ? _EmptyExerciseResults(onClear: _clearDiscoveryFilters)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showRecent) ...[
                        _SectionHeader(
                          title: localizations.recentExercises,
                          count: recentExercises.length,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SizedBox(
                          height: 78,
                          child: ListView.separated(
                            key: const ValueKey<String>(
                              'recent-exercises-list',
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: recentExercises.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final definition = _catalog.definitionFor(
                                recentExercises[index],
                              );
                              return _RecentExerciseCard(
                                definition: definition,
                                onTap: () => _handleExerciseTap(definition),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _SectionHeader(
                        title: _resultSectionTitle(localizations),
                        count: definitions.length,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (
                        var index = 0;
                        index < definitions.length;
                        index++
                      ) ...[
                        _buildExerciseCard(definitions[index]),
                        if (index != definitions.length - 1)
                          const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<ExerciseDefinition> _filteredDefinitions(
    AppLocalizations localizations,
  ) {
    return _catalog.definitions
        .where((definition) {
          final matchesRegion =
              _selectedRegion == null ||
              definition.type.bodyRegion == _selectedRegion;
          if (!matchesRegion) {
            return false;
          }

          if (_query.isEmpty) {
            return true;
          }

          final content = localizedExerciseGuideContent(
            content: _guideCatalog.contentFor(definition.type),
            isTurkish: localizations.isTurkish,
          );
          final regionLabel = _bodyRegionLabel(
            localizations,
            definition.type.bodyRegion,
          );
          final searchableText = <String>[
            localizations.exerciseTitle(definition.type.id),
            definition.type.title,
            content.subtitle,
            content.purpose,
            regionLabel,
          ].join(' ').toLowerCase();

          return searchableText.contains(_query);
        })
        .toList(growable: false);
  }

  Widget _buildExerciseCard(ExerciseDefinition definition) {
    final localizations = AppLocalizations.of(context);
    final content = localizedExerciseGuideContent(
      content: _guideCatalog.contentFor(definition.type),
      isTurkish: localizations.isTurkish,
    );

    return _ExerciseSelectionCard(
      definition: definition,
      content: content,
      onTap: () => _handleExerciseTap(definition),
      onGuideTap: () => _openGuide(definition.type),
    );
  }

  String _resultSectionTitle(AppLocalizations localizations) {
    if (_query.isNotEmpty) {
      return localizations.exerciseSearchResults;
    }
    final selectedRegion = _selectedRegion;
    if (selectedRegion != null) {
      return _bodyRegionLabel(localizations, selectedRegion);
    }
    return localizations.allExercises;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _clearDiscoveryFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedRegion = null;
      _isCategoryExpanded = false;
    });
  }

  void _handleExerciseTap(ExerciseDefinition definition) {
    if (!definition.isAnalysisSupported) {
      _openGuide(definition.type);
      return;
    }

    unawaited(
      ref.read(recentExercisesProvider.notifier).record(definition.type),
    );
    ref.read(selectedExerciseProvider.notifier).state = definition.type;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
    );
  }

  void _openGuide(ExerciseType exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GuideScreen(initialExercise: exercise)),
    );
  }
}

class _ExerciseDiscoveryHeader extends StatelessWidget {
  const _ExerciseDiscoveryHeader({
    required this.searchController,
    required this.selectedRegion,
    required this.isCategoryExpanded,
    required this.analysisReadyCount,
    required this.guideCount,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.onToggleCategory,
    required this.onRegionSelected,
  });

  final TextEditingController searchController;
  final ExerciseBodyRegion? selectedRegion;
  final bool isCategoryExpanded;
  final int analysisReadyCount;
  final int guideCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onToggleCategory;
  final ValueChanged<ExerciseBodyRegion?> onRegionSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final filters = <ExerciseBodyRegion?>[null, ...ExerciseBodyRegion.values];
    final selectedLabel = selectedRegion == null
        ? localizations.all
        : _bodyRegionLabel(localizations, selectedRegion!);
    final padding = AppLayout.of(context).pagePadding.copyWith(bottom: 10);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurfaceCard(
            variant: AppSurfaceVariant.accent,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.analysisAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: colors.analysisAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.exerciseDiscoveryTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: AppFontWeights.heavy,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            localizations.exerciseDiscoveryBody,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.foregroundMuted,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppStatusChip(
                      label: localizations.analysisReadyCount(
                        analysisReadyCount,
                      ),
                      tone: AppStatusTone.accent,
                      icon: Icons.center_focus_strong_rounded,
                    ),
                    AppStatusChip(
                      label: localizations.guideLibraryCount(guideCount),
                      tone: AppStatusTone.neutral,
                      icon: Icons.menu_book_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey<String>('exercise-search-field'),
            controller: searchController,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: localizations.searchExercises,
              hintText: localizations.searchExercisesHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey<String>('clear-exercise-search'),
                      tooltip: localizations.clearSearch,
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.compact),
            child: InkWell(
              key: const ValueKey<String>('exercise-category-selector'),
              borderRadius: BorderRadius.circular(AppRadii.compact),
              onTap: onToggleCategory,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppTouchTargets.minimum,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.compact),
                  border: Border.all(
                    color: isCategoryExpanded
                        ? colors.analysisAccent
                        : colors.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.accessibility_new_rounded,
                      size: 19,
                      color: colors.foregroundMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.exerciseCategories,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.foregroundSubtle,
                                  fontWeight: AppFontWeights.bold,
                                ),
                          ),
                          Text(
                            selectedLabel,
                            key: const ValueKey<String>(
                              'selected-exercise-category',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: AppFontWeights.heavy,
                                ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      key: const ValueKey<String>('exercise-category-arrow'),
                      turns: isCategoryExpanded ? 0.5 : 0,
                      duration: AppMotion.resolveDuration(
                        context,
                        AppMotionDurations.fast,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isCategoryExpanded) ...[
            const SizedBox(height: AppSpacing.xs),
            AppSurfaceCard(
              key: const ValueKey<String>('exercise-category-options'),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < filters.length; index++) ...[
                    _CategoryOption(
                      region: filters[index],
                      selected: selectedRegion == filters[index],
                      onTap: () => onRegionSelected(filters[index]),
                    ),
                    if (index != filters.length - 1)
                      Divider(height: 1, color: colors.outlineSubtle),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.region,
    required this.selected,
    required this.onTap,
  });

  final ExerciseBodyRegion? region;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final label = region == null
        ? localizations.all
        : _bodyRegionLabel(localizations, region!);

    return InkWell(
      key: ValueKey<String>('exercise-category-${region?.name ?? 'all'}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTargets.minimum),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? colors.analysisAccent
                        : colors.foregroundMuted,
                    fontWeight: selected
                        ? AppFontWeights.heavy
                        : AppFontWeights.semibold,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 19,
                  color: colors.analysisAccent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
        ),
        Text(
          localizations.exerciseResultCount(count),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.foregroundSubtle,
            fontWeight: AppFontWeights.semibold,
          ),
        ),
      ],
    );
  }
}

class _RecentExerciseCard extends StatelessWidget {
  const _RecentExerciseCard({required this.definition, required this.onTap});

  final ExerciseDefinition definition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    return SizedBox(
      width: 168,
      child: AppSurfaceCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('recent-exercise-card-${definition.type.id}'),
            borderRadius: BorderRadius.circular(AppRadii.surface),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.analysisAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: colors.analysisAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.exerciseTitle(definition.type.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.foreground,
                                fontWeight: AppFontWeights.heavy,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _bodyRegionLabel(
                            localizations,
                            definition.type.bodyRegion,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.foregroundSubtle),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: colors.foregroundSubtle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyExerciseResults extends StatelessWidget {
  const _EmptyExerciseResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.muted,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: colors.analysisAccent,
            size: 42,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            localizations.noExercisesFound,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.noExercisesFoundBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const ValueKey<String>('clear-exercise-filters'),
            label: localizations.clearExerciseFilters,
            onPressed: onClear,
            variant: AppButtonVariant.outline,
            icon: Icons.refresh_rounded,
          ),
        ],
      ),
    );
  }
}

class _ExerciseSelectionCard extends StatelessWidget {
  const _ExerciseSelectionCard({
    required this.definition,
    required this.content,
    required this.onTap,
    required this.onGuideTap,
  });

  final ExerciseDefinition definition;
  final ExerciseGuideContent content;
  final VoidCallback onTap;
  final VoidCallback onGuideTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final isActive = definition.isAnalysisSupported;
    final title = localizations.exerciseTitle(definition.type.id);
    final bodyRegion = _bodyRegionLabel(
      localizations,
      definition.type.bodyRegion,
    );
    final trackingType = _trackingTypeLabel(context, definition.trackingType);
    final actionLabel = isActive
        ? localizations.startAnalysis
        : localizations.openGuide;

    return Semantics(
      button: true,
      enabled: true,
      label: '$title, $bodyRegion, $trackingType',
      hint: actionLabel,
      child: AppSurfaceCard(
        padding: EdgeInsets.zero,
        variant: isActive
            ? AppSurfaceVariant.standard
            : AppSurfaceVariant.muted,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>(
              'exercise-selection-card-${definition.type.id}',
            ),
            borderRadius: BorderRadius.circular(AppRadii.surface),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colors.analysisAccent.withValues(alpha: 0.12)
                          : colors.foreground.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Icon(
                      isActive
                          ? Icons.center_focus_strong_rounded
                          : Icons.menu_book_rounded,
                      size: 22,
                      color: isActive
                          ? colors.analysisAccent
                          : colors.foregroundSubtle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.foreground,
                                fontWeight: AppFontWeights.heavy,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          content.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.foregroundMuted,
                                height: 1.3,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xxs,
                          children: [
                            AppStatusChip(
                              label: '$bodyRegion • $trackingType',
                              showIcon: false,
                            ),
                            if (!isActive)
                              AppStatusChip(
                                label: localizations.guideAvailable,
                                tone: AppStatusTone.neutral,
                                icon: Icons.menu_book_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppIconButton(
                    key: ValueKey<String>(
                      'exercise-guide-action-${definition.type.id}',
                    ),
                    icon: Icons.menu_book_outlined,
                    tooltip: localizations.openGuide,
                    onPressed: onGuideTap,
                    variant: AppIconButtonVariant.standard,
                    iconSize: 20,
                  ),
                ],
              ),
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

String _trackingTypeLabel(
  BuildContext context,
  ExerciseTrackingType trackingType,
) {
  final localizations = AppLocalizations.of(context);
  return switch (trackingType) {
    ExerciseTrackingType.repetitions => localizations.pick(
      tr: 'Tekrar',
      en: 'Repetitions',
    ),
    ExerciseTrackingType.hold => localizations.pick(
      tr: 'Sabit duruş',
      en: 'Hold',
    ),
  };
}
