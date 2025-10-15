import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<UserCredential> signInWithEmailPassword({required String email, required String password});
  Future<UserCredential> registerWithEmailPassword({required String email, required String password});
  Future<void> signOut();
  Stream<User?> authState();
  Future<void> sendPasswordResetEmail({required String email});
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  FirebaseAuthRepository(this._auth);

  @override
  Future<UserCredential> signInWithEmailPassword({required String email, required String password}) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<UserCredential> registerWithEmailPassword({required String email, required String password}) async {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Stream<User?> authState() => _auth.authStateChanges();

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
