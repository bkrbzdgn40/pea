import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';

class AnalysisSelectionRequiredView extends StatelessWidget {
  const AnalysisSelectionRequiredView({
    super.key,
    required this.title,
    required this.message,
    required this.onSelectExercise,
  });

  final String title;
  final String message;
  final VoidCallback onSelectExercise;

  @override
  Widget build(BuildContext context) {
    const pagePadding = 24.0;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimumContentHeight = constraints.maxHeight > pagePadding * 2
              ? constraints.maxHeight - pagePadding * 2
              : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(pagePadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minimumContentHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AppEmptyView(
                    centered: true,
                    icon: Icons.directions_run_rounded,
                    title: title,
                    message: message,
                    actionLabel: AppLocalizations.of(context).selectExercise,
                    onAction: onSelectExercise,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
