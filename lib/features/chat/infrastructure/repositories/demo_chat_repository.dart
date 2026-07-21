import '../../../../app/localization/app_localizations.dart';
import '../../application/repositories/chat_repository.dart';
import '../../presentation/models/chat_message.dart';

class DemoChatRepository implements ChatRepository {
  const DemoChatRepository({required AppLocalizations localizations})
    : _localizations = localizations;

  final AppLocalizations _localizations;

  @override
  Future<List<ChatMessage>> loadInitialMessages() async {
    final now = DateTime.now();

    return [
      ChatMessage(
        id: 'coach_welcome',
        text: _localizations.coachWelcomeMessage,
        isFromCoach: true,
        createdAt: now,
      ),
      ChatMessage(
        id: 'coach_hint',
        text: _localizations.coachPersonalizationHint,
        isFromCoach: true,
        createdAt: now,
      ),
    ];
  }

  @override
  Future<ChatMessage> sendMessage(String text) async {
    final now = DateTime.now();

    return ChatMessage(
      id: 'coach_${now.microsecondsSinceEpoch}',
      text: _responseFor(text),
      isFromCoach: true,
      createdAt: now,
    );
  }

  String _responseFor(String text) {
    final normalized = text.toLowerCase();

    if (normalized.contains('squat')) {
      return _localizations.coachSquatReply;
    }

    if (normalized.contains('form')) {
      return _localizations.coachFormReply;
    }

    if (normalized.contains('program') ||
        normalized.contains('antrenman') ||
        normalized.contains('workout') ||
        normalized.contains('plan')) {
      return _localizations.coachPlanReply;
    }

    return _localizations.coachDefaultReply;
  }
}
