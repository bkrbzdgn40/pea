import '../../domain/models/exercise_type.dart';
import '../models/exercise_guide_content.dart';
import 'exercise_guide_contents.dart';

class ExerciseGuideCatalog {
  const ExerciseGuideCatalog();

  static final Map<ExerciseType, ExerciseGuideContent> _contentsByType =
      _buildContentsByType(exerciseGuideContents);

  List<ExerciseGuideContent> get contents => exerciseGuideContents;

  ExerciseGuideContent contentFor(ExerciseType type) {
    final content = _contentsByType[type];
    if (content != null) {
      return content;
    }

    throw StateError('Missing exercise guide content for: $type');
  }

  ExerciseGuideContent? contentForIdOrNull(String id) {
    final type = ExerciseType.fromIdOrNull(id);
    if (type == null) {
      return null;
    }

    return _contentsByType[type];
  }

  static Map<ExerciseType, ExerciseGuideContent> _buildContentsByType(
    List<ExerciseGuideContent> contents,
  ) {
    final contentsByType = <ExerciseType, ExerciseGuideContent>{};
    for (final content in contents) {
      final previous = contentsByType[content.type];
      if (previous != null) {
        throw StateError(
          'Duplicate exercise guide content registered for ${content.type}.',
        );
      }
      contentsByType[content.type] = content;
    }

    return Map.unmodifiable(contentsByType);
  }
}
