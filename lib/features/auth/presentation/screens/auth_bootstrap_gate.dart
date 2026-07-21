import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../workout_analysis/presentation/screens/home_screen.dart';
import '../providers/auth_bootstrap_provider.dart';

class AuthBootstrapGate extends ConsumerWidget {
  const AuthBootstrapGate({super.key});

  @override
  // Uygulama açılır açılmaz auth bootstrap durumunu dinler ve kullanıcı hazırsa
  // ana ekrana, değilse yüklenme ya da hata görünümüne yönlendirir.
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final bootstrapState = ref.watch(authBootstrapProvider);

    return bootstrapState.when(
      loading: () => const _AuthBootstrapLoadingView(),
      error: (error, _) => _AuthBootstrapErrorView(
        message: localizations.sessionPreparationFailed,
        onRetry: () => ref.invalidate(authBootstrapProvider),
      ),
      data: (state) {
        if (state.isReady) {
          return const HomeScreen();
        }

        return _AuthBootstrapErrorView(
          message: localizations.sessionPreparationFailed,
          onRetry: () => ref.invalidate(authBootstrapProvider),
        );
      },
    );
  }
}

class _AuthBootstrapLoadingView extends StatelessWidget {
  const _AuthBootstrapLoadingView();

  @override
  // Auth bootstrap çalışırken kullanıcıya siyah temalı basit bir yüklenme ekranı gösterir.
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.greenAccent),
              const SizedBox(height: 18),
              Text(
                localizations.preparingSession,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBootstrapErrorView extends StatelessWidget {
  const _AuthBootstrapErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  // Oturum hazırlığı başarısız olduğunda hata mesajını ve yeniden deneme aksiyonunu gösterir.
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: Colors.greenAccent,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(localizations.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
