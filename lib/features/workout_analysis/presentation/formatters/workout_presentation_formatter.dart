class WorkoutPresentationFormatter {
  const WorkoutPresentationFormatter._();

  static String exerciseTitle(String exerciseType) {
    return exerciseType
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static String duration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String holdDuration(double seconds) {
    return duration(Duration(seconds: seconds.round()));
  }

  static String roundedScore(double score) {
    return score.round().toString();
  }

  static String compactScore(double score) {
    return score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1);
  }

  static String dateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}
