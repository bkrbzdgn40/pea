class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    required this.isAnonymous,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? isAnonymous,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}
