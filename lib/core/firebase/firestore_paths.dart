class FirestorePaths {
  const FirestorePaths._();

  static const usersCollection = 'users';
  static const sessionsSubcollection = 'sessions';
  static const repsSubcollection = 'reps';
  static const goalsSubcollection = 'goals';
  static const progressContributionsSubcollection = 'progressContributions';
  static const activityDaysSubcollection = 'activityDays';
  static const rewardsSubcollection = 'rewards';
  static const achievementEventsSubcollection = 'achievementEvents';

  static String userDoc(String uid) {
    return '$usersCollection/$uid';
  }

  static String userGoals(String uid) {
    return '${userDoc(uid)}/$goalsSubcollection';
  }

  static String userGoalDoc(String uid, String goalId) {
    return '${userGoals(uid)}/$goalId';
  }

  static String userProgressContributions(String uid) {
    return '${userDoc(uid)}/$progressContributionsSubcollection';
  }

  static String userProgressContributionDoc(String uid, String sessionId) {
    return '${userProgressContributions(uid)}/$sessionId';
  }

  static String userActivityDays(String uid) {
    return '${userDoc(uid)}/$activityDaysSubcollection';
  }

  static String userActivityDayDoc(String uid, String localDate) {
    return '${userActivityDays(uid)}/$localDate';
  }

  static String userAchievementEvents(String uid) {
    return '${userDoc(uid)}/$achievementEventsSubcollection';
  }

  static String userAchievementEventDoc(String uid, String eventId) {
    return '${userAchievementEvents(uid)}/$eventId';
  }

  static String userRewards(String uid) {
    return '${userDoc(uid)}/$rewardsSubcollection';
  }

  static String userRewardDoc(String uid, String rewardId) {
    return '${userRewards(uid)}/$rewardId';
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
