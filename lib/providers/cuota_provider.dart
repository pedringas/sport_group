import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/cuota_repository.dart';
import '../data/models/cuota_model.dart';
import '../data/models/pago_model.dart';
import '../data/models/enums.dart';
import 'auth_provider.dart';

final cuotaRepositoryProvider = Provider<CuotaRepository>((ref) => CuotaRepository());

final cuotasProvider = StreamProvider.family<List<CuotaModel>, String>((ref, grupoId) {
  return ref.watch(cuotaRepositoryProvider).getCuotas(grupoId);
});

final cuotaProvider = FutureProvider.family<CuotaModel?, ({String grupoId, String cuotaId})>(
    (ref, args) => ref.watch(cuotaRepositoryProvider).getCuota(args.grupoId, args.cuotaId));

final pagosDeCuotaProvider =
    StreamProvider.family<List<PagoModel>, ({String grupoId, String cuotaId})>(
        (ref, args) =>
            ref.watch(cuotaRepositoryProvider).getPagosDeCuota(args.grupoId, args.cuotaId));

/// Mis pagos aprobados en un grupo — para la sección Caja (egresos).
final misPagosAprobadosProvider =
    StreamProvider.family<List<PagoModel>, ({String grupoId, String uid})>(
        (ref, args) => ref
            .watch(cuotaRepositoryProvider)
            .getMisPagosAprobados(args.grupoId, args.uid));

/// Admin: all pagos for a group (stream).
final pagosGrupoProvider = StreamProvider.family<List<PagoModel>, String>(
    (ref, grupoId) =>
        ref.watch(cuotaRepositoryProvider).getPagosDeGrupo(grupoId));

/// Current user's own pagos for a group — works for any member without
/// triggering the Firestore 10-get() limit on security rule evaluation.
typedef PagosGrupoUidKey = ({String grupoId, String uid});

final misPagosGrupoProvider =
    StreamProvider.family<List<PagoModel>, PagosGrupoUidKey>((ref, args) =>
        ref.watch(cuotaRepositoryProvider)
            .getMisPagosGrupo(args.grupoId, args.uid));

final miPagoProvider = StreamProvider.family<PagoModel?, ({String grupoId, String cuotaId})>(
    (ref, args) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(cuotaRepositoryProvider).getMiPago(args.grupoId, args.cuotaId, uid);
});

// ── CrearCuota notifier ───────────────────────────────────────────────────────

class CrearCuotaNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates a single (non-recurring) cuota.
  Future<void> crear({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double monto,
    required DateTime vencimiento,
    List<String>? miembrosUids,
    List<String>? excluidosUids,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(cuotaRepositoryProvider).createCuota(
            grupoId: grupoId,
            titulo: titulo,
            descripcion: descripcion,
            monto: monto,
            vencimiento: vencimiento,
            miembrosUids: miembrosUids,
            excluidosUids: excluidosUids,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Creates a full recurring series of cuotas.
  Future<void> crearSerie({
    required String grupoId,
    required String titulo,
    String? descripcion,
    required double monto,
    required DateTime primerVencimiento,
    required FrecuenciaCuota frecuencia,
    required int totalCuotas,
    List<String>? miembrosUids,
    List<String>? excluidosUids,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(cuotaRepositoryProvider).createCuotasSerie(
            grupoId: grupoId,
            titulo: titulo,
            descripcion: descripcion,
            monto: monto,
            primerVencimiento: primerVencimiento,
            frecuencia: frecuencia,
            totalCuotas: totalCuotas,
            miembrosUids: miembrosUids,
            excluidosUids: excluidosUids,
          );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final crearCuotaProvider =
    AsyncNotifierProvider<CrearCuotaNotifier, void>(CrearCuotaNotifier.new);
