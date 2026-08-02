import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/localization/app_localizations.dart';
import '../../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../../app/theme/app_design_tokens.dart';
import '../../../application/saved_workout_plan.dart';

class SavedPlansSection extends StatelessWidget {
  const SavedPlansSection({
    super.key,
    required this.plans,
    required this.selectedPlanId,
    required this.onSelect,
    required this.onDelete,
    required this.onNew,
    required this.onReview,
  });

  final AsyncValue<List<SavedWorkoutPlan>> plans;
  final String? selectedPlanId;
  final ValueChanged<SavedWorkoutPlan> onSelect;
  final ValueChanged<SavedWorkoutPlan> onDelete;
  final VoidCallback onNew;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.savedPlans,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey<String>('new-workout-plan'),
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded),
                label: Text(localizations.newPlan),
              ),
            ],
          ),
          const SizedBox(height: 4),
          plans.when(
            data: (items) {
              if (items.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      localizations.noSavedPlans,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 14),
                    ReviewSelectedPlanButton(onPressed: null),
                  ],
                );
              }
              return Column(
                key: const ValueKey<String>('saved-workout-plan-list'),
                children: [
                  for (var index = 0; index < items.length; index += 1) ...[
                    SavedPlanTile(
                      plan: items[index],
                      isSelected: items[index].id == selectedPlanId,
                      onTap: () => onSelect(items[index]),
                      onDelete: () => onDelete(items[index]),
                    ),
                    if (index != items.length - 1) const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 14),
                  ReviewSelectedPlanButton(onPressed: onReview),
                ],
              );
            },
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(),
                SizedBox(height: 14),
                ReviewSelectedPlanButton(onPressed: null),
              ],
            ),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.savedPlansLoadFailed,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                const SizedBox(height: 14),
                ReviewSelectedPlanButton(onPressed: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SavedPlanTile extends StatelessWidget {
  const SavedPlanTile({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  final SavedWorkoutPlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final accent = Colors.greenAccent;
    return AnimatedContainer(
      key: ValueKey<String>('saved-plan-card-${plan.id}'),
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? accent.withValues(alpha: 0.58)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('load-plan-${plan.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? accent : Colors.white38,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        localizations.savedPlanSummary(
                          exercises: plan.entries.length,
                          sets: plan.totalSets,
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('delete-plan-${plan.id}'),
                  tooltip: localizations.deletePlan,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReviewSelectedPlanButton extends StatelessWidget {
  const ReviewSelectedPlanButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return ElevatedButton.icon(
      key: const ValueKey<String>('review-selected-workout-plan'),
      onPressed: onPressed,
      icon: const Icon(Icons.summarize_rounded),
      label: Text(localizations.reviewPlan),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.black,
      ),
    );
  }
}
