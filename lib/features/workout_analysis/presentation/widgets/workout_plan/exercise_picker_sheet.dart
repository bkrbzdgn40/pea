import 'package:flutter/material.dart';

import '../../../../../app/localization/app_localizations.dart';
import '../../../application/exercise_catalog.dart';
import '../../../application/exercise_definition_metadata.dart';

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({super.key});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
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
