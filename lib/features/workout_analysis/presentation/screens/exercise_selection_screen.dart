import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_definition.dart';
import '../data/exercise_guide_catalog.dart';
import '../data/localized_exercise_guide_content.dart';
import '../models/exercise_guide_content.dart';
import '../providers/selected_exercise_provider.dart';
import 'camera_permission_screen.dart';

class ExerciseSelectionScreen extends ConsumerWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    const catalog = ExerciseCatalog();
    const guideCatalog = ExerciseGuideCatalog();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(localizations.selectExercise),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: catalog.definitions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final definition = catalog.definitions[index];
            final content = localizedExerciseGuideContent(
              content: guideCatalog.contentFor(definition.type),
              isTurkish: localizations.isTurkish,
            );
            return _ExerciseSelectionCard(
              content: content,
              isAnalysisSupported: definition.isAnalysisSupported,
              onTap: () => _handleExerciseTap(context, ref, definition),
            );
          },
        ),
      ),
    );
  }

  void _handleExerciseTap(
    BuildContext context,
    WidgetRef ref,
    ExerciseDefinition definition,
  ) {
    if (!definition.isAnalysisSupported) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.exerciseNotActiveForAnalysis)),
      );
      return;
    }

    ref.read(selectedExerciseProvider.notifier).state = definition.type;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
    );
  }
}

class _ExerciseSelectionCard extends StatelessWidget {
  const _ExerciseSelectionCard({
    required this.content,
    required this.isAnalysisSupported,
    required this.onTap,
  });

  final ExerciseGuideContent content;
  final bool isAnalysisSupported;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = isAnalysisSupported;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.greenAccent : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.greenAccent.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isActive
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                color: isActive ? Colors.greenAccent : Colors.white54,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).exerciseTitle(content.type.id),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    content.subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isActive
                        ? AppLocalizations.of(context).analysisActive
                        : AppLocalizations.of(context).guideOnlyForNow,
                    style: TextStyle(
                      color: isActive ? Colors.greenAccent : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: isActive ? Colors.greenAccent : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }
}
