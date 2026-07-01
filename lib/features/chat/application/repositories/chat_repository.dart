import '../../presentation/models/chat_message.dart';

abstract interface class ChatRepository {
  Future<List<ChatMessage>> loadInitialMessages();

  Future<ChatMessage> sendMessage(String text);
}
