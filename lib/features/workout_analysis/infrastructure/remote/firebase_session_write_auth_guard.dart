import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../../core/firebase/firebase_failures.dart';

abstract interface class SessionWriteAuthGuard {
  Future<SessionWriteAuthSnapshot> verifyOwner({
    required String ownerId,
    required bool reloadUser,
    required bool forceRefresh,
  });
}

class FirebaseSessionWriteAuthGuard implements SessionWriteAuthGuard {
  const FirebaseSessionWriteAuthGuard(this._firebaseAuth);

  final firebase_auth.FirebaseAuth _firebaseAuth;

  @override
  Future<SessionWriteAuthSnapshot> verifyOwner({
    required String ownerId,
    required bool reloadUser,
    required bool forceRefresh,
  }) async {
    var user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        message: 'No authenticated user is available for the session write.',
      );
    }

    if (reloadUser) {
      try {
        await user.reload();
      } on firebase_auth.FirebaseAuthException catch (error, stackTrace) {
        throw AuthFailure(
          message: 'Authenticated user could not be reloaded.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthFailure(
          message: 'Authenticated user disappeared after reload.',
        );
      }
    }

    if (user.uid != ownerId) {
      throw AuthFailure(
        message: 'Authenticated user does not match the workout session owner.',
        cause: StateError('authUid=${user.uid}, ownerId=$ownerId'),
      );
    }

    try {
      final tokenResult = await user.getIdTokenResult(forceRefresh);
      final claims = tokenResult.claims ?? const <String, dynamic>{};
      return SessionWriteAuthSnapshot(
        uid: user.uid,
        isAnonymous: user.isAnonymous,
        reloadedUser: reloadUser,
        forcedTokenRefresh: forceRefresh,
        tokenPresent: tokenResult.token?.isNotEmpty ?? false,
        audience: claims['aud']?.toString(),
        subject: claims['sub']?.toString(),
        userIdClaim: claims['user_id']?.toString(),
        signInProvider: tokenResult.signInProvider,
        authTime: tokenResult.authTime,
        issuedAtTime: tokenResult.issuedAtTime,
        expirationTime: tokenResult.expirationTime,
      );
    } on firebase_auth.FirebaseAuthException catch (error, stackTrace) {
      throw AuthFailure(
        message: 'Firebase Auth token could not be refreshed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class SessionWriteAuthSnapshot {
  const SessionWriteAuthSnapshot({
    required this.uid,
    required this.isAnonymous,
    required this.reloadedUser,
    required this.forcedTokenRefresh,
    required this.tokenPresent,
    this.audience,
    this.subject,
    this.userIdClaim,
    this.signInProvider,
    this.authTime,
    this.issuedAtTime,
    this.expirationTime,
  });

  final String uid;
  final bool isAnonymous;
  final bool reloadedUser;
  final bool forcedTokenRefresh;
  final bool tokenPresent;
  final String? audience;
  final String? subject;
  final String? userIdClaim;
  final String? signInProvider;
  final DateTime? authTime;
  final DateTime? issuedAtTime;
  final DateTime? expirationTime;

  Map<String, Object?> toDiagnosticJson() {
    return <String, Object?>{
      'uid': uid,
      'isAnonymous': isAnonymous,
      'reloadedUser': reloadedUser,
      'forcedTokenRefresh': forcedTokenRefresh,
      'tokenPresent': tokenPresent,
      'audience': audience,
      'subject': subject,
      'userIdClaim': userIdClaim,
      'signInProvider': signInProvider,
      'authTime': authTime?.toIso8601String(),
      'issuedAtTime': issuedAtTime?.toIso8601String(),
      'expirationTime': expirationTime?.toIso8601String(),
    };
  }
}
