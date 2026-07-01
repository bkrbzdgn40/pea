class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isFromCoach,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool isFromCoach;
  final DateTime createdAt;
}
