import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../../core/firebase/firebase_failures.dart';
import '../../application/repositories/auth_repository.dart';
import '../../domain/models/auth_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository(this._firebaseAuth);

  final firebase_auth.FirebaseAuth _firebaseAuth;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_toAuthUser);
  }

  @override
  AuthUser? get currentUser {
    return _toAuthUser(_firebaseAuth.currentUser);
  }

  @override
  String? get currentUserId {
    return _firebaseAuth.currentUser?.uid;
  }

  @override
  Future<void> signInAnonymously() async {
    try {
      await _firebaseAuth.signInAnonymously();
    } on firebase_auth.FirebaseAuthException catch (error, stackTrace) {
      throw AuthFailure(
        message: 'Anonymous sign-in failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on firebase_auth.FirebaseAuthException catch (error, stackTrace) {
      throw AuthFailure(
        message: 'Sign-out failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  AuthUser? _toAuthUser(firebase_auth.User? user) {
    if (user == null) {
      return null;
    }

    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      isAnonymous: user.isAnonymous,
    );
  }
}
