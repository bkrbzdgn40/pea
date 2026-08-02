int displayWholeSeconds(double seconds) {
  if (!seconds.isFinite || seconds <= 0) {
    return 0;
  }
  return Duration(milliseconds: (seconds * 1000).round()).inSeconds;
}

int displayScore(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.toInt();
}

String formatHoldSeconds(int seconds) {
  final duration = Duration(seconds: seconds);
  final minutes = duration.inMinutes;
  final remainingSeconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  return '$minutes:$remainingSeconds';
}
