import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/chat/infrastructure/repositories/demo_chat_repository.dart';

void main() {
  test('uses Turkish coach copy when Turkish is active', () async {
    final repository = DemoChatRepository(
      localizations: const AppLocalizations(Locale('tr')),
    );

    final initial = await repository.loadInitialMessages();
    final reply = await repository.sendMessage('squat formu');

    expect(initial.first.text, contains('AI Coach'));
    expect(initial.first.text, contains('Merhaba'));
    expect(reply.text, contains('dizlerini'));
  });

  test('uses English coach copy when English is active', () async {
    final repository = DemoChatRepository(
      localizations: const AppLocalizations(Locale('en')),
    );

    final initial = await repository.loadInitialMessages();
    final reply = await repository.sendMessage('workout plan');

    expect(initial.first.text, contains('Hi, I am AI Coach'));
    expect(reply.text, contains('short plan'));
  });
}
