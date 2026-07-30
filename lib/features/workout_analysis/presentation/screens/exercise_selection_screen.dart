import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_definition.dart';
import '../../application/exercise_definition_metadata.dart';
import '../../domain/models/exercise_type.dart';
import '../data/exercise_guide_catalog.dart';
import '../data/localized_exercise_guide_content.dart';
import '../providers/recent_exercises_provider.dart';
import '../providers/selected_exercise_provider.dart';
import 'camera_permission_screen.dart';

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

    return AppScaffoldShell(
      title: localizations.selectExercise,
      currentPage: AppDestination.exerciseSelection,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          _ExerciseDiscoveryHeader(
            searchController: _searchController,
            selectedRegion: _selectedRegion,
            isCategoryExpanded: _isCategoryExpanded,
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
          Expanded(
            child: definitions.isEmpty
                ? _EmptyExerciseResults(onClear: _clearDiscoveryFilters)
                : ListView(
                    key: const PageStorageKey<String>(
                      'exercise-selection-results',
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                    children: [
                      if (showRecent) ...[
                        _SectionHeader(
                          title: localizations.recentExercises,
                          count: recentExercises.length,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 64,
                          child: ListView.separated(
                            key: const ValueKey<String>(
                              'recent-exercises-list',
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: recentExercises.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
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
                        const SizedBox(height: 16),
                      ],
                      _SectionHeader(
                        title: _resultSectionTitle(localizations),
                        count: definitions.length,
                      ),
                      const SizedBox(height: 8),
                      for (
                        var index = 0;
                        index < definitions.length;
                        index++
                      ) ...[
                        _buildExerciseCard(definitions[index]),
                        if (index != definitions.length - 1)
                          const SizedBox(height: 8),
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
            regionLabel,
          ].join(' ').toLowerCase();

          return searchableText.contains(_query);
        })
        .toList(growable: false);
  }

  Widget _buildExerciseCard(ExerciseDefinition definition) {
    return _ExerciseSelectionCard(
      definition: definition,
      onTap: () => _handleExerciseTap(definition),
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
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.exerciseNotActiveForAnalysis)),
      );
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
}

class _ExerciseDiscoveryHeader extends StatelessWidget {
  const _ExerciseDiscoveryHeader({
    required this.searchController,
    required this.selectedRegion,
    required this.isCategoryExpanded,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.onToggleCategory,
    required this.onRegionSelected,
  });

  final TextEditingController searchController;
  final ExerciseBodyRegion? selectedRegion;
  final bool isCategoryExpanded;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onToggleCategory;
  final ValueChanged<ExerciseBodyRegion?> onRegionSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final filters = <ExerciseBodyRegion?>[null, ...ExerciseBodyRegion.values];
    final selectedLabel = selectedRegion == null
        ? localizations.all
        : _bodyRegionLabel(localizations, selectedRegion!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              filled: true,
              fillColor: const Color(0xFF151515),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.greenAccent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: const ValueKey<String>('exercise-category-selector'),
              borderRadius: BorderRadius.circular(14),
              onTap: onToggleCategory,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCategoryExpanded
                        ? Colors.greenAccent
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.accessibility_new_rounded,
                      size: 19,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.exerciseCategories,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            selectedLabel,
                            key: const ValueKey<String>(
                              'selected-exercise-category',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      key: const ValueKey<String>('exercise-category-arrow'),
                      turns: isCategoryExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isCategoryExpanded) ...[
            const SizedBox(height: 8),
            Material(
              key: const ValueKey<String>('exercise-category-options'),
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < filters.length; index++) ...[
                      _CategoryOption(
                        region: filters[index],
                        selected: selectedRegion == filters[index],
                        onTap: () => onRegionSelected(filters[index]),
                      ),
                      if (index != filters.length - 1)
                        const Divider(height: 1, color: Colors.white10),
                    ],
                  ],
                ),
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
    final label = region == null
        ? localizations.all
        : _bodyRegionLabel(localizations, region!);

    return InkWell(
      key: ValueKey<String>('exercise-category-${region?.name ?? 'all'}'),
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.greenAccent : Colors.white70,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 19,
                  color: Colors.greenAccent,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          localizations.exerciseResultCount(count),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
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
    return SizedBox(
      width: 150,
      child: Material(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey<String>('recent-exercise-card-${definition.type.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 17,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.exerciseTitle(definition.type.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _EmptyExerciseResults extends StatelessWidget {
  const _EmptyExerciseResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.white38,
            ),
            const SizedBox(height: 14),
            Text(
              localizations.noExercisesFound,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              localizations.noExercisesFoundBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.35),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey<String>('clear-exercise-filters'),
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(localizations.clearExerciseFilters),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseSelectionCard extends StatelessWidget {
  const _ExerciseSelectionCard({required this.definition, required this.onTap});

  final ExerciseDefinition definition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isActive = definition.isAnalysisSupported;
    final title = localizations.exerciseTitle(definition.type.id);
    final bodyRegion = _bodyRegionLabel(
      localizations,
      definition.type.bodyRegion,
    );
    final trackingType = _trackingTypeLabel(context, definition.trackingType);

    return Semantics(
      button: true,
      enabled: isActive,
      label: '$title, $bodyRegion, $trackingType',
      child: Material(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey<String>(
            'exercise-selection-card-${definition.type.id}',
          ),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.greenAccent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.play_arrow_rounded
                        : Icons.lock_outline_rounded,
                    size: 21,
                    color: isActive ? Colors.greenAccent : Colors.white54,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$bodyRegion • $trackingType',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isActive) ...[
                  Text(
                    localizations.guideOnlyForNow,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: isActive ? Colors.greenAccent : Colors.white30,
                ),
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
