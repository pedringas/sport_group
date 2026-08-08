import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/notificacion_repository.dart';
import '../data/models/actividad_model.dart';
import '../data/models/notificacion_rol_model.dart';
import '../core/config/app_config.dart';
import 'auth_provider.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final notificacionRepositoryProvider =
    Provider<NotificacionRepository>((ref) => NotificacionRepository());

// ── Actividad del grupo (one-shot + refresh) ──────────────────────────────────

/// Actividad reciente de Tacheros.
/// Use RefreshIndicator + ref.invalidate to reload.
final actividadAgregadaProvider =
    FutureProvider.autoDispose<List<ActividadModel>>((ref) async {
  final repo = ref.read(notificacionRepositoryProvider);
  final all = await repo.getActividadOnce(kGrupoId);
  return all..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

// ── Rol notifications (live stream) ──────────────────────────────────────────

final notificacionesRolProvider =
    StreamProvider.autoDispose<List<NotificacionRolModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref
      .read(notificacionRepositoryProvider)
      .getNotificacionesRol(uid);
});

// ── Unread count (for badge) ──────────────────────────────────────────────────

final unreadRolCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(0);
  return ref.read(notificacionRepositoryProvider).getUnreadCount(uid);
});
