import '../../application/repositories/chat_repository.dart';
import '../../presentation/models/chat_message.dart';

class DemoChatRepository implements ChatRepository {
  const DemoChatRepository();

  @override
  Future<List<ChatMessage>> loadInitialMessages() async {
    final now = DateTime.now();

    return [
      ChatMessage(
        id: 'coach_welcome',
        text:
            'Merhaba, ben AI Coach. Form, squat tekniği veya antrenman planı hakkında kısa öneriler verebilirim.',
        isFromCoach: true,
        createdAt: now,
      ),
      ChatMessage(
        id: 'coach_hint',
        text:
            'Canlı analiz verilerin geliştikçe burada daha kişisel öneriler görebileceksin.',
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
      return 'Squat için dizlerini ayak parmaklarınla aynı hatta tutmaya ve inişi kontrollü yapmaya odaklan.';
    }

    if (normalized.contains('form')) {
      return 'Formu düzeltmek için tekrar hızını biraz düşür, gövdeni sabit tut ve hareket aralığını koru.';
    }

    if (normalized.contains('program') || normalized.contains('antrenman')) {
      return 'Bugün kısa bir plan iyi olabilir: ısınma, 3 kontrollü set ve set aralarında yeterli dinlenme.';
    }

    return 'İyi gidiyorsun. Kısa, kontrollü setlerle form kalitesini korumaya devam et.';
  }
}
