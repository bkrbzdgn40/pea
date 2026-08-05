class FirestorePaths {
  const FirestorePaths._();

  static const usersCollection = 'users';
  static const sessionsSubcollection = 'sessions';
  static const repsSubcollection = 'reps';
  static const goalsSubcollection = 'goals';

  static String userDoc(String uid) {
    return '$usersCollection/$uid';
  }

  static String userGoals(String uid) {
    return '${userDoc(uid)}/$goalsSubcollection';
  }

  static String userGoalDoc(String uid, String goalId) {
    return '${userGoals(uid)}/$goalId';
  }

  static String userSessions(String uid) {
    return '${userDoc(uid)}/$sessionsSubcollection';
  }

  static String userSessionDoc(String uid, String sessionId) {
    return '${userSessions(uid)}/$sessionId';
  }

  static String userSessionReps(String uid, String sessionId) {
    return '${userSessionDoc(uid, sessionId)}/$repsSubcollection';
  }

  static String userSessionRepDoc(String uid, String sessionId, String repId) {
    return '${userSessionReps(uid, sessionId)}/$repId';
  }
}
