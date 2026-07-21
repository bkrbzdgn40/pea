import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/workout_live_metrics.dart';

/// Rich, non-persisted metrics captured immediately before a live session ends.
///
/// The persisted WorkoutSession remains the durable source of truth. This
/// provider only carries engine-owned metrics such as tempo consistency,
/// stability, and bilateral asymmetry into the immediate summary screen.
final completedSessionMetricsProvider =
    StateProvider<WorkoutLiveMetricsSnapshot?>((ref) => null);
