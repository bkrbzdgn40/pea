import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);

    return AppScaffoldShell(
      title: 'Ayarlar',
      currentPage: AppDestination.settings,
      padding: EdgeInsets.zero,
      body: settingsState.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _SettingsSection(
                title: 'Kamera',
                children: [
                  _SettingsDropdownTile<WorkoutCameraPreference>(
                    title: 'Kamera tercihi',
                    value: settings.cameraPreference,
                    values: WorkoutCameraPreference.values,
                    labelFor: (preference) => preference.label,
                    onChanged: (preference) {
                      if (preference == null) return;

                      unawaited(
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setCameraPreference(preference),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _SettingsDropdownTile<WorkoutCameraQuality>(
                    title: 'Görüntü kalitesi',
                    value: settings.cameraQuality,
                    values: WorkoutCameraQuality.values,
                    labelFor: (quality) => quality.label,
                    onChanged: (quality) {
                      if (quality == null) return;

                      unawaited(
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setCameraQuality(quality),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
        loading: () {
          return const Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          );
        },
        error: (error, _) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    color: Colors.greenAccent,
                    size: 40,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ayarlar yüklenemedi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.invalidate(settingsControllerProvider),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsDropdownTile<T> extends StatelessWidget {
  const _SettingsDropdownTile({
    required this.title,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        labelFor(value),
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
      trailing: DropdownButton<T>(
        value: value,
        dropdownColor: const Color(0xFF202020),
        underline: const SizedBox.shrink(),
        iconEnabledColor: Colors.greenAccent,
        style: const TextStyle(color: Colors.white),
        items: values
            .map(
              (item) =>
                  DropdownMenuItem<T>(value: item, child: Text(labelFor(item))),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
