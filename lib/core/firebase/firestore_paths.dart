class FirestorePaths {
  const FirestorePaths._();

  static const usersCollection = 'users';
  static const sessionsSubcollection = 'sessions';

  static String userDoc(String uid) {
    return '$usersCollection/$uid';
  }

  static String userSessions(String uid) {
    return '${userDoc(uid)}/$sessionsSubcollection';
  }

  static String userSessionDoc(String uid, String sessionId) {
    return '${userSessions(uid)}/$sessionId';
  }
}
