import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to Turkish when no language preference is stored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(settingsControllerProvider.future);

    expect(settings.language, AppLanguage.turkish);
    expect(container.read(runtimeAppLanguageProvider), AppLanguage.turkish);
  });

  test('loads and persists the selected application language', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.language': AppLanguage.english.name,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initial = await container.read(settingsControllerProvider.future);
    expect(initial.language, AppLanguage.english);
    expect(container.read(runtimeAppLanguageProvider), AppLanguage.english);

    await container
        .read(settingsControllerProvider.notifier)
        .setLanguage(AppLanguage.turkish);

    expect(
      container.read(settingsControllerProvider).valueOrNull?.language,
      AppLanguage.turkish,
    );
    expect(container.read(runtimeAppLanguageProvider), AppLanguage.turkish);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('settings.language'),
      AppLanguage.turkish.name,
    );
  });

  test('runtime localization follows the selected language', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appLocalizationsProvider).ttsLanguageTag, 'tr-TR');

    container.read(runtimeAppLanguageProvider.notifier).state =
        AppLanguage.english;

    expect(container.read(appLocalizationsProvider).ttsLanguageTag, 'en-US');
    expect(
      container.read(appLocalizationsProvider).assessmentCompletedFeedback,
      'Assessment completed.',
    );
  });
}
