import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout_analysis/presentation/screens/home_screen.dart';
import '../providers/auth_bootstrap_provider.dart';

class AuthBootstrapGate extends ConsumerWidget {
  const AuthBootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(authBootstrapProvider);

    return bootstrapState.when(
      loading: () => const _AuthBootstrapLoadingView(),
      error: (error, _) => _AuthBootstrapErrorView(
        message: 'Kullanıcı oturumu hazırlanamadı.',
        onRetry: () => ref.invalidate(authBootstrapProvider),
      ),
      data: (state) {
        if (state.isReady) {
          return const HomeScreen();
        }

        return _AuthBootstrapErrorView(
          message: state.errorMessage ?? 'Kullanıcı oturumu hazırlanamadı.',
          onRetry: () => ref.invalidate(authBootstrapProvider),
        );
      },
    );
  }
}

class _AuthBootstrapLoadingView extends StatelessWidget {
  const _AuthBootstrapLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.greenAccent),
              SizedBox(height: 18),
              Text(
                'Oturum hazırlanıyor...',
                style: TextStyle(color: Colors.white, fontSize: 16),
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
  Widget build(BuildContext context) {
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
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
