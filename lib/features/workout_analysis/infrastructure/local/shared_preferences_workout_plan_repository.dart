import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/saved_workout_plan.dart';

class SharedPreferencesWorkoutPlanRepository implements WorkoutPlanRepository {
  const SharedPreferencesWorkoutPlanRepository();

  static const String storageKey = 'saved_workout_plans_v1';

  @override
  Future<List<SavedWorkoutPlan>> loadPlans() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return const <SavedWorkoutPlan>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <SavedWorkoutPlan>[];
      }

      final plans = <SavedWorkoutPlan>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final plan = SavedWorkoutPlan.fromJson(Map<String, Object?>.from(item));
        if (plan != null) {
          plans.add(plan);
        }
      }
      plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return List<SavedWorkoutPlan>.unmodifiable(plans);
    } on FormatException {
      return const <SavedWorkoutPlan>[];
    }
  }

  @override
  Future<void> savePlan(SavedWorkoutPlan plan) async {
    final plans = List<SavedWorkoutPlan>.from(await loadPlans());
    plans.removeWhere((existing) => existing.id == plan.id);
    plans.insert(0, plan);
    await _write(plans);
  }

  @override
  Future<void> deletePlan(String planId) async {
    final plans = List<SavedWorkoutPlan>.from(await loadPlans())
      ..removeWhere((plan) => plan.id == planId);
    await _write(plans);
  }

  Future<void> _write(List<SavedWorkoutPlan> plans) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      plans.map((plan) => plan.toJson()).toList(growable: false),
    );
    final saved = await preferences.setString(storageKey, encoded);
    if (!saved) {
      throw StateError('Workout plan could not be saved locally.');
    }
  }
}
