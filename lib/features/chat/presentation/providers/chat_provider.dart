import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/repositories/chat_repository.dart';
import '../../infrastructure/repositories/demo_chat_repository.dart';
import '../models/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return const DemoChatRepository();
});

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    final controller = ChatController(ref.watch(chatRepositoryProvider));
    unawaited(controller.loadInitialMessages());
    return controller;
  },
);

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isSending = false,
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repository) : super(const ChatState());

  final ChatRepository _repository;

  Future<void> loadInitialMessages() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final messages = await _repository.loadInitialMessages();
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Mesajlar yüklenemedi. Lütfen tekrar dene.',
      );
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || state.isSending) return;

    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: 'user_${now.microsecondsSinceEpoch}',
      text: trimmedText,
      isFromCoach: false,
      createdAt: now,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      clearError: true,
    );

    try {
      final coachMessage = await _repository.sendMessage(trimmedText);
      state = state.copyWith(
        messages: [...state.messages, coachMessage],
        isSending: false,
      );
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Mesaj gönderilemedi. Lütfen tekrar dene.',
      );
    }
  }
}
