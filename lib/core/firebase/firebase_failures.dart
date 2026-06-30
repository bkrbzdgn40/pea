class FirebaseAppFailure implements Exception {
  const FirebaseAppFailure({
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final causeText = cause == null ? '' : ' Cause: $cause';
    return '$runtimeType: $message$causeText';
  }
}

class FirebaseBootstrapFailure extends FirebaseAppFailure {
  const FirebaseBootstrapFailure({
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

class FirestoreFailure extends FirebaseAppFailure {
  const FirestoreFailure({
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

class AuthFailure extends FirebaseAppFailure {
  const AuthFailure({required super.message, super.cause, super.stackTrace});
}
