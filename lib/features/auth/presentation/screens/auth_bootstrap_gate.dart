import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../workout_analysis/presentation/screens/home_screen.dart';
import '../providers/auth_bootstrap_provider.dart';

class AuthBootstrapGate extends ConsumerWidget {
  const AuthBootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final bootstrapState = ref.watch(authBootstrapProvider);

    return bootstrapState.when(
      loading: () => AppRootStateScaffold(
        child: AppLoadingView(message: localizations.preparingSession),
      ),
      error: (error, _) => AppRootStateScaffold(
        child: AppErrorView(
          icon: Icons.lock_outline_rounded,
          message: localizations.sessionPreparationFailed,
          actionLabel: localizations.retry,
          onAction: () => ref.invalidate(authBootstrapProvider),
        ),
      ),
      data: (state) {
        if (state.isReady) {
          return const HomeScreen();
        }

        return AppRootStateScaffold(
          child: AppErrorView(
            icon: Icons.lock_outline_rounded,
            message: localizations.sessionPreparationFailed,
            actionLabel: localizations.retry,
            onAction: () => ref.invalidate(authBootstrapProvider),
          ),
        );
      },
    );
  }
}
