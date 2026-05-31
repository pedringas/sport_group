import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/notificacion_repository.dart';
import '../data/models/actividad_model.dart';
import '../data/models/notificacion_rol_model.dart';
import 'auth_provider.dart';
import 'grupo_provider.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final notificacionRepositoryProvider =
    Provider<NotificacionRepository>((ref) => NotificacionRepository());

// ── Actividad agregada (multi-grupo, one-shot + refresh) ──────────────────────

/// Fetches recent actividad from all user groups in parallel and merges them.
/// Use RefreshIndicator + ref.invalidate to reload.
final actividadAgregadaProvider =
    FutureProvider.autoDispose<List<ActividadModel>>((ref) async {
  final grupos = await ref.watch(userGruposProvider.future);
  if (grupos.isEmpty) return [];
  final repo = ref.read(notificacionRepositoryProvider);
  final results = await Future.wait(
    grupos.map((g) => repo.getActividadOnce(g.id)),
  );
  final all = results.expand((l) => l).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all;
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
