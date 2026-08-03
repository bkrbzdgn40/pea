import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_definition.dart';
import '../../domain/models/exercise_type.dart';
import '../data/exercise_guide_catalog.dart';
import '../data/localized_exercise_guide_content.dart';
import '../models/exercise_guide_content.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, this.initialExercise});

  final ExerciseType? initialExercise;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  static const _catalog = ExerciseCatalog();
  static const _guideCatalog = ExerciseGuideCatalog();

  final TextEditingController _searchController = TextEditingController();
  ExerciseDifficulty? _selectedDifficulty;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final definitions = _filteredDefinitions(localizations);
    final analysisReadyCount = _catalog.definitions
        .where((definition) => definition.isAnalysisSupported)
        .length;
    final resultsPadding = AppLayout.of(context).pagePadding.copyWith(top: 2);

    return AppScaffoldShell(
      title: localizations.exerciseGuide,
      currentPage: AppDestination.guide,
      padding: EdgeInsets.zero,
      body: ListView(
        key: const PageStorageKey<String>('exercise-guide-results'),
        padding: EdgeInsets.zero,
        children: [
          _GuideDiscoveryHeader(
            searchController: _searchController,
            selectedDifficulty: _selectedDifficulty,
            analysisReadyCount: analysisReadyCount,
            guideCount: _catalog.definitions.length,
            onQueryChanged: (value) {
              setState(() => _query = value.trim().toLowerCase());
            },
            onClearSearch: _clearSearch,
            onDifficultyChanged: (difficulty) {
              setState(() => _selectedDifficulty = difficulty);
            },
          ),
          Padding(
            padding: resultsPadding,
            child: definitions.isEmpty
                ? _GuideEmptyState(onClear: _clearFilters)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var index = 0;
                        index < definitions.length;
                        index++
                      ) ...[
                        _buildGuideCard(
                          definition: definitions[index],
                          localizations: localizations,
                        ),
                        if (index != definitions.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required ExerciseDefinition definition,
    required AppLocalizations localizations,
  }) {
    final content = localizedExerciseGuideContent(
      content: _guideCatalog.contentFor(definition.type),
      isTurkish: localizations.isTurkish,
    );

    return _ExerciseGuideCard(
      content: content,
      isAnalysisSupported: definition.isAnalysisSupported,
      initiallyExpanded: definition.type == widget.initialExercise,
    );
  }

  List<ExerciseDefinition> _filteredDefinitions(
    AppLocalizations localizations,
  ) {
    final definitions = _catalog.definitions
        .where((definition) {
          final content = localizedExerciseGuideContent(
            content: _guideCatalog.contentFor(definition.type),
            isTurkish: localizations.isTurkish,
          );
          final matchesDifficulty =
              _selectedDifficulty == null ||
              content.difficulty == _selectedDifficulty;
          if (!matchesDifficulty) {
            return false;
          }

          if (_query.isEmpty) {
            return true;
          }

          final searchableText = <String>[
            localizations.exerciseTitle(definition.type.id),
            definition.type.title,
            content.subtitle,
            content.purpose,
            localizations.difficultyLabel(content.difficulty.name),
            ...content.tips,
            ...content.commonMistakes,
          ].join(' ').toLowerCase();
          return searchableText.contains(_query);
        })
        .toList(growable: true);

    final initialExercise = widget.initialExercise;
    if (initialExercise != null) {
      final initialIndex = definitions.indexWhere(
        (definition) => definition.type == initialExercise,
      );
      if (initialIndex > 0) {
        final initialDefinition = definitions.removeAt(initialIndex);
        definitions.insert(0, initialDefinition);
      }
    }

    return definitions;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedDifficulty = null;
    });
  }
}

class _GuideDiscoveryHeader extends StatelessWidget {
  const _GuideDiscoveryHeader({
    required this.searchController,
    required this.selectedDifficulty,
    required this.analysisReadyCount,
    required this.guideCount,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.onDifficultyChanged,
  });

  final TextEditingController searchController;
  final ExerciseDifficulty? selectedDifficulty;
  final int analysisReadyCount;
  final int guideCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<ExerciseDifficulty?> onDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final padding = AppLayout.of(context).pagePadding.copyWith(bottom: 10);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurfaceCard(
            variant: AppSurfaceVariant.strong,
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
                        color: colors.analysisAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: colors.analysisAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.exerciseGuideIntroTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: AppFontWeights.heavy,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            localizations.exerciseGuideIntroBody,
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
                      label: localizations.guideLibraryCount(guideCount),
                      tone: AppStatusTone.neutral,
                      icon: Icons.library_books_rounded,
                    ),
                    AppStatusChip(
                      label: localizations.analysisReadyCount(
                        analysisReadyCount,
                      ),
                      tone: AppStatusTone.accent,
                      icon: Icons.center_focus_strong_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey<String>('guide-search-field'),
            controller: searchController,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: localizations.searchExercises,
              hintText: localizations.searchGuideHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey<String>('clear-guide-search'),
                      tooltip: localizations.clearSearch,
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _DifficultyFilter(
            selectedDifficulty: selectedDifficulty,
            onChanged: onDifficultyChanged,
          ),
        ],
      ),
    );
  }
}

class _DifficultyFilter extends StatelessWidget {
  const _DifficultyFilter({
    required this.selectedDifficulty,
    required this.onChanged,
  });

  final ExerciseDifficulty? selectedDifficulty;
  final ValueChanged<ExerciseDifficulty?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipButton(
            label: AppLocalizations.of(context).all,
            isSelected: selectedDifficulty == null,
            onTap: () => onChanged(null),
          ),
          for (final difficulty in ExerciseDifficulty.values) ...[
            const SizedBox(width: AppSpacing.xs),
            _FilterChipButton(
              key: ValueKey<String>(
                'guide-difficulty-filter-${difficulty.name}',
              ),
              label: AppLocalizations.of(
                context,
              ).difficultyLabel(difficulty.name),
              tone: _difficultyTone(difficulty),
              isSelected: selectedDifficulty == difficulty,
              onTap: () => onChanged(difficulty),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.tone = AppStatusTone.neutral,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final toneColor = tone.resolveColor(colors);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: toneColor.withValues(alpha: 0.08),
      selectedColor: toneColor.withValues(alpha: 0.22),
      side: BorderSide(
        color: toneColor.withValues(alpha: isSelected ? 1 : 0.48),
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: toneColor,
        fontWeight: AppFontWeights.heavy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    );
  }
}

class _ExerciseGuideCard extends StatelessWidget {
  const _ExerciseGuideCard({
    required this.content,
    required this.isAnalysisSupported,
    required this.initiallyExpanded,
  });

  final ExerciseGuideContent content;
  final bool isAnalysisSupported;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: ValueKey<String>('exercise-guide-card-${content.type.id}'),
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('exercise-guide-${content.type.id}'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          iconColor: colors.analysisAccent,
          collapsedIconColor: colors.foregroundMuted,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(
              isAnalysisSupported
                  ? Icons.center_focus_strong_rounded
                  : Icons.menu_book_rounded,
              color: isAnalysisSupported
                  ? colors.analysisAccent
                  : colors.foregroundSubtle,
            ),
          ),
          title: Text(
            localizations.exerciseTitle(content.type.id),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    AppStatusChip(
                      key: ValueKey<String>(
                        'exercise-guide-difficulty-${content.type.id}',
                      ),
                      label: localizations.difficultyLabel(
                        content.difficulty.name,
                      ),
                      tone: _difficultyTone(content.difficulty),
                      icon: Icons.signal_cellular_alt_rounded,
                    ),
                    if (!isAnalysisSupported)
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
          children: [
            _GuideTextBlock(
              icon: Icons.flag_outlined,
              title: localizations.purpose,
              text: content.purpose,
            ),
            const SizedBox(height: AppSpacing.sm),
            _GuideSection(
              icon: Icons.tune_rounded,
              title: localizations.setup,
              items: content.setupSteps,
            ),
            const SizedBox(height: AppSpacing.sm),
            _GuideSection(
              icon: Icons.lightbulb_outline_rounded,
              title: localizations.techniqueTips,
              items: content.tips,
            ),
            const SizedBox(height: AppSpacing.sm),
            _GuideSection(
              icon: Icons.report_problem_outlined,
              title: localizations.commonMistakes,
              items: content.commonMistakes,
              tone: AppStatusTone.caution,
            ),
            const SizedBox(height: AppSpacing.md),
            _VideoButton(content: content),
          ],
        ),
      ),
    );
  }
}

class _GuideTextBlock extends StatelessWidget {
  const _GuideTextBlock({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return AppSurfaceCard(
      variant: AppSurfaceVariant.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuideSectionTitle(icon: icon, title: title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.items,
    this.tone = AppStatusTone.accent,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final bulletColor = tone.resolveColor(colors);

    return AppSurfaceCard(
      variant: AppSurfaceVariant.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuideSectionTitle(icon: icon, title: title, tone: tone),
          const SizedBox(height: AppSpacing.xs),
          for (var index = 0; index < items.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: bulletColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    items[index],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.foregroundMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (index != items.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _GuideSectionTitle extends StatelessWidget {
  const _GuideSectionTitle({
    required this.icon,
    required this.title,
    this.tone = AppStatusTone.accent,
  });

  final IconData icon;
  final String title;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Row(
      children: [
        Icon(icon, size: 18, color: tone.resolveColor(colors)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoButton extends StatelessWidget {
  const _VideoButton({required this.content});

  final ExerciseGuideContent content;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.muted,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sourceLabel = Text(
            localizations.source(content.youtubeSourceLabel),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.foregroundSubtle,
              fontWeight: AppFontWeights.semibold,
            ),
          );
          final button = AppButton(
            label: localizations.watchOnYoutube,
            onPressed: () => _openVideo(context, content.youtubeUrl),
            variant: AppButtonVariant.ghost,
            icon: Icons.open_in_new_rounded,
          );

          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sourceLabel,
                const SizedBox(height: AppSpacing.xs),
                button,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: sourceLabel),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: button),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openVideo(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!didLaunch && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).videoLinkOpenFailed),
        ),
      );
    }
  }
}

AppStatusTone _difficultyTone(ExerciseDifficulty difficulty) {
  return switch (difficulty) {
    ExerciseDifficulty.beginner => AppStatusTone.success,
    ExerciseDifficulty.intermediate => AppStatusTone.caution,
    ExerciseDifficulty.advanced => AppStatusTone.danger,
  };
}

class _GuideEmptyState extends StatelessWidget {
  const _GuideEmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppEmptyView(
      centered: true,
      icon: Icons.menu_book_outlined,
      title: localizations.noGuideResults,
      message: localizations.noGuideResultsBody,
      actionLabel: localizations.clearGuideFilters,
      onAction: onClear,
    );
  }
}
