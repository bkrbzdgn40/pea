import '../../domain/models/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  String? get currentUserId;

  Future<void> signInAnonymously();

  Future<void> signOut();
}
