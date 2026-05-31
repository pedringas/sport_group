import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import '../datasources/auth_datasource.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  final AuthDatasource _ds = AuthDatasource();

  User? get currentUser => _ds.currentUser;
  Stream<User?> get authStateChanges => _ds.authStateChanges;

  Future<void> sendOtp({
    required String phone,
    required Function(PhoneAuthCredential) onAutoVerified,
    required Function(String, int?) onCodeSent,
    required Function(FirebaseAuthException) onError,
  }) =>
      _ds.sendOtp(
        phone: phone,
        onAutoVerified: onAutoVerified,
        onCodeSent: onCodeSent,
        onError: onError,
      );

  Future<UserCredential> verifyOtp(String verificationId, String smsCode) =>
      _ds.verifyOtp(verificationId, smsCode);

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _ds.signInWithEmail(email, password);

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
  }) =>
      _ds.signUpWithEmail(
          email: email, password: password, nombre: nombre, apellido: apellido);

  Future<void> sendPasswordReset(String email) => _ds.sendPasswordReset(email);

  Future<UserCredential> signInWithGoogle() => _ds.signInWithGoogle();

  Future<void> signOut() => _ds.signOut();

  Future<bool> userExists(String uid) => _ds.userExists(uid);

  Future<void> createUser(UsuarioModel user) => _ds.createUser(user);

  Future<UsuarioModel?> getUser(String uid) => _ds.getUser(uid);

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _ds.updateUser(uid, data);

  Future<void> saveFcmToken(String uid, String token) =>
      _ds.saveFcmToken(uid, token);

  Future<String?> uploadAvatar(String uid, Uint8List bytes) =>
      _ds.uploadAvatar(uid, bytes);
}
