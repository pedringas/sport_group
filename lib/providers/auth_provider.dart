import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/usuario_model.dart';
import '../services/notification_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UsuarioModel?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(authRepositoryProvider).getUser(user.uid);
});

// Auth flow state
sealed class AuthFlowState {}
class AuthIdle extends AuthFlowState {}
class AuthSendingOtp extends AuthFlowState {}
class AuthOtpSent extends AuthFlowState {
  final String verificationId;
  final int? forceResendToken;
  AuthOtpSent(this.verificationId, this.forceResendToken);
}
class AuthVerifying extends AuthFlowState {}
class AuthDone extends AuthFlowState {}
class AuthError extends AuthFlowState {
  final String message;
  AuthError(this.message);
}

class AuthFlowNotifier extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => AuthIdle();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> sendOtp(String phone) async {
    state = AuthSendingOtp();
    await _repo.sendOtp(
      phone: phone,
      onAutoVerified: (credential) async {
        state = AuthVerifying();
        await FirebaseAuth.instance.signInWithCredential(credential);
        await NotificationService.instance.onUserLoggedIn();
        state = AuthDone();
      },
      onCodeSent: (verificationId, token) {
        state = AuthOtpSent(verificationId, token);
      },
      onError: (e) {
        state = AuthError(_mapError(e.code));
      },
    );
  }

  Future<void> verifyOtp(String verificationId, String smsCode) async {
    state = AuthVerifying();
    try {
      await _repo.verifyOtp(verificationId, smsCode);
      try { await NotificationService.instance.onUserLoggedIn(); } catch (_) {}
      state = AuthDone();
    } on FirebaseAuthException catch (e) {
      state = AuthError(_mapError(e.code));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = AuthVerifying();
    try {
      await _repo.signInWithEmail(email, password);
      try { await NotificationService.instance.onUserLoggedIn(); } catch (_) {}
      state = AuthDone();
    } on FirebaseAuthException catch (e) {
      state = AuthError(_mapEmailError(e.code));
    } catch (e) {
      state = AuthError('Error al iniciar sesión: $e');
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
  }) async {
    state = AuthVerifying();
    try {
      await _repo.signUpWithEmail(
          email: email, password: password, nombre: nombre, apellido: apellido);
      // Notifications are best-effort — don't let them block registration
      try {
        await NotificationService.instance.onUserLoggedIn();
      } catch (_) {}
      state = AuthDone();
    } on FirebaseAuthException catch (e) {
      state = AuthError(_mapEmailError(e.code));
    } catch (e) {
      state = AuthError('Error al registrarse: $e');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _repo.sendPasswordReset(email);
    } catch (_) {}
  }

  Future<void> signInWithGoogle() async {
    state = AuthVerifying();
    try {
      await _repo.signInWithGoogle();
      try { await NotificationService.instance.onUserLoggedIn(); } catch (_) {}
      state = AuthDone();
    } catch (e) {
      state = AuthError('Error al iniciar sesión con Google: $e');
    }
  }

  @visibleForTesting
  static String mapEmailError(String code) => switch (code) {
        'user-not-found' => 'No existe una cuenta con ese email',
        'wrong-password' => 'Contraseña incorrecta',
        'invalid-credential' => 'Email o contraseña incorrectos',
        'email-already-in-use' => 'Ese email ya está registrado',
        'weak-password' => 'La contraseña debe tener al menos 6 caracteres',
        'invalid-email' => 'Email inválido',
        'too-many-requests' => 'Demasiados intentos. Esperá un momento',
        'user-disabled' => 'Esta cuenta fue deshabilitada',
        _ => 'Error de autenticación. Intentá de nuevo',
      };

  String _mapEmailError(String code) => mapEmailError(code);

  Future<void> signOut() async {
    await _repo.signOut();
    state = AuthIdle();
  }

  void reset() => state = AuthIdle();

  @visibleForTesting
  static String mapError(String code) => switch (code) {
        'invalid-phone-number' => 'Número de teléfono inválido',
        'too-many-requests' => 'Demasiados intentos. Esperá unos minutos',
        'invalid-verification-code' => 'Código incorrecto',
        'session-expired' => 'El código expiró. Solicitá uno nuevo',
        'quota-exceeded' => 'Límite de SMS alcanzado. Intentá más tarde',
        _ => 'Error de autenticación. Intentá de nuevo',
      };

  String _mapError(String code) => mapError(code);
}

final authFlowProvider = NotifierProvider<AuthFlowNotifier, AuthFlowState>(
  AuthFlowNotifier.new,
);
