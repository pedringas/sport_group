import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/usuario_model.dart';

class AuthDatasource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOtp({
    required String phone,
    required Function(PhoneAuthCredential) onAutoVerified,
    required Function(String, int?) onCodeSent,
    required Function(FirebaseAuthException) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: onAutoVerified,
      verificationFailed: onError,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> verifyOtp(String verificationId, String smsCode) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  // ── Email / Password ─────────────────────────────────────────────────────────

  Future<UserCredential> signInWithEmail(
      String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return result;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await _ensureUserProfileEmail(
        result.user!, nombre: nombre, apellido: apellido);
    return result;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> _ensureUserProfileEmail(User firebaseUser,
      {required String nombre, required String apellido}) async {
    final doc =
        await _db.collection('usuarios').doc(firebaseUser.uid).get();
    if (doc.exists) return;
    await _db.collection('usuarios').doc(firebaseUser.uid).set({
      'nombre': nombre,
      'apellido': apellido,
      'telefono': '',
      'email': firebaseUser.email,
      'avatarUrl': null,
      'fcmToken': null,
      'createdAt': Timestamp.now(),
    });
  }

  Future<UserCredential> signInWithGoogle() async {
    UserCredential result;

    if (kIsWeb) {
      // Web: use Firebase's built-in popup flow
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      result = await _auth.signInWithPopup(provider);
    } else {
      // Mobile: use google_sign_in package
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      result = await _auth.signInWithCredential(credential);
    }

    // Auto-create Firestore profile if this is a new user
    await _ensureUserProfile(result.user!);

    return result;
  }

  /// Creates the Firestore user document from Google profile data if it doesn't exist.
  Future<void> _ensureUserProfile(User firebaseUser) async {
    final doc = await _db.collection('usuarios').doc(firebaseUser.uid).get();
    if (doc.exists) return; // already has a profile

    // Split display name into first/last
    final parts = (firebaseUser.displayName ?? '').trim().split(' ');
    final nombre = parts.isNotEmpty ? parts.first : 'Usuario';
    final apellido = parts.length > 1 ? parts.skip(1).join(' ') : '';

    await _db.collection('usuarios').doc(firebaseUser.uid).set({
      'nombre': nombre,
      'apellido': apellido,
      'telefono': firebaseUser.phoneNumber ?? '',
      'email': firebaseUser.email,
      'avatarUrl': firebaseUser.photoURL,
      'fcmToken': null,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<bool> userExists(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    return doc.exists;
  }

  Future<void> createUser(UsuarioModel user) async {
    await _db.collection('usuarios').doc(user.uid).set(user.toMap());
  }

  Future<UsuarioModel?> getUser(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return null;
    return UsuarioModel.fromFirestore(doc);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).update(data);
  }

  Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection('usuarios').doc(uid).update({'fcmToken': token});
  }

  /// Uploads avatar bytes to Storage and returns the download URL.
  Future<String?> uploadAvatar(String uid, Uint8List bytes) async {
    final ref = _storage.ref('usuarios/$uid/avatar.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
