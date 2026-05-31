import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gasto_model.dart';
import '../models/grupo_gasto_model.dart';

class GastoRepository {
  final _db = FirebaseFirestore.instance;

  // ── Grupos de gastos ────────────────────────────────────────────────────────

  Stream<List<GrupoGastoModel>> getGruposGasto(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gruposGasto')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(GrupoGastoModel.fromFirestore).toList());
  }

  Future<String> createGrupoGasto({
    required String grupoId,
    required String nombre,
    String? descripcion,
    required String creadoPorUid,
    required String creadoPorNombre,
  }) async {
    final ref = _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gruposGasto')
        .doc();
    await ref.set({
      'grupoId': grupoId,
      'nombre': nombre,
      'descripcion': descripcion,
      'cerrado': false,
      'creadoPorUid': creadoPorUid,
      'creadoPorNombre': creadoPorNombre,
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  Future<void> cerrarGrupoGasto(String grupoId, String grupoGastoId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gruposGasto')
        .doc(grupoGastoId)
        .update({'cerrado': true, 'cerradoAt': Timestamp.now()});
  }

  Future<void> reabrirGrupoGasto(String grupoId, String grupoGastoId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gruposGasto')
        .doc(grupoGastoId)
        .update({'cerrado': false, 'cerradoAt': null});
  }

  Future<void> deleteGrupoGasto(String grupoId, String grupoGastoId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gruposGasto')
        .doc(grupoGastoId)
        .delete();
  }

  // ── Gastos ──────────────────────────────────────────────────────────────────

  Stream<List<GastoModel>> getGastos(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gastos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GastoModel.fromFirestore).toList());
  }

  Stream<List<GastoModel>> getGastosPorGrupoGasto(
      String grupoId, String? grupoGastoId) {
    if (grupoGastoId == null) {
      return _db
          .collection('grupos')
          .doc(grupoId)
          .collection('gastos')
          .where('grupoGastoId', isNull: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(GastoModel.fromFirestore).toList());
    }
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gastos')
        .where('grupoGastoId', isEqualTo: grupoGastoId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GastoModel.fromFirestore).toList());
  }

  Future<void> createGasto({
    required String grupoId,
    required String pagadorUid,
    required String pagadorNombre,
    required String titulo,
    String? descripcion,
    required double monto,
    required List<ParticipanteGasto> participantes,
    required CategoriaGasto categoria,
    TipoMovimiento tipo = TipoMovimiento.gasto,
    String? grupoGastoId,
    DateTime? fecha,
  }) async {
    final fechaTs = Timestamp.fromDate(fecha ?? DateTime.now());
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gastos')
        .add({
      'grupoId': grupoId,
      if (grupoGastoId != null) 'grupoGastoId': grupoGastoId,
      'pagadorUid': pagadorUid,
      'pagadorNombre': pagadorNombre,
      'titulo': titulo,
      'descripcion': descripcion,
      'monto': monto,
      'participantes': participantes.map((p) => p.toMap()).toList(),
      'categoria': categoria.name,
      'tipo': tipo.name,
      'fecha': fechaTs,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateGasto({
    required String grupoId,
    required String gastoId,
    required String titulo,
    String? descripcion,
    required double monto,
    required List<ParticipanteGasto> participantes,
    required CategoriaGasto categoria,
    TipoMovimiento tipo = TipoMovimiento.gasto,
    String? grupoGastoId,
    DateTime? fecha,
  }) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gastos')
        .doc(gastoId)
        .update({
      'titulo': titulo,
      'descripcion': descripcion,
      'monto': monto,
      'participantes': participantes.map((p) => p.toMap()).toList(),
      'categoria': categoria.name,
      'tipo': tipo.name,
      if (grupoGastoId != null) 'grupoGastoId': grupoGastoId,
      if (fecha != null) 'fecha': Timestamp.fromDate(fecha),
    });
  }

  Future<void> deleteGasto(String grupoId, String gastoId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('gastos')
        .doc(gastoId)
        .delete();
  }

  // ── Liquidaciones ───────────────────────────────────────────────────────────

  Stream<List<LiquidacionModel>> getLiquidaciones(String grupoId) {
    return _db
        .collection('grupos')
        .doc(grupoId)
        .collection('liquidaciones')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LiquidacionModel.fromFirestore).toList());
  }

  Future<void> createLiquidacion({
    required String grupoId,
    required String deudorUid,
    required String deudorNombre,
    required String acreedorUid,
    required String acreedorNombre,
    required double monto,
    String? grupoGastoId,
  }) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('liquidaciones')
        .add({
      'grupoId': grupoId,
      if (grupoGastoId != null) 'grupoGastoId': grupoGastoId,
      'deudorUid': deudorUid,
      'deudorNombre': deudorNombre,
      'acreedorUid': acreedorUid,
      'acreedorNombre': acreedorNombre,
      'monto': monto,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> deleteLiquidacion(String grupoId, String liqId) async {
    await _db
        .collection('grupos')
        .doc(grupoId)
        .collection('liquidaciones')
        .doc(liqId)
        .delete();
  }

  // ── Balance computation ─────────────────────────────────────────────────────

  /// Computes the net balance for [currentUid] against every other member.
  /// Only [TipoMovimiento.gasto] entries create debts; ingresos are ignored.
  static List<BalanceConMiembro> computeBalances({
    required String currentUid,
    required List<GastoModel> gastos,
    required List<LiquidacionModel> liquidaciones,
  }) {
    final Map<String, double> balances = {};
    final Map<String, String> nombres = {};

    // Only gastos (not ingresos) generate debts between members
    for (final g in gastos.where((g) => g.tipo == TipoMovimiento.gasto)) {
      if (g.pagadorUid == currentUid) {
        for (final p in g.participantes) {
          if (p.uid != currentUid) {
            balances[p.uid] = (balances[p.uid] ?? 0) + p.monto;
            nombres[p.uid] = p.nombre;
          }
        }
      } else {
        final myShare =
            g.participantes.where((p) => p.uid == currentUid).firstOrNull;
        if (myShare != null) {
          balances[g.pagadorUid] =
              (balances[g.pagadorUid] ?? 0) - myShare.monto;
          nombres[g.pagadorUid] = g.pagadorNombre;
        }
      }
    }

    for (final l in liquidaciones) {
      if (l.deudorUid == currentUid) {
        balances[l.acreedorUid] =
            (balances[l.acreedorUid] ?? 0) + l.monto;
        nombres[l.acreedorUid] = l.acreedorNombre;
      } else if (l.acreedorUid == currentUid) {
        balances[l.deudorUid] =
            (balances[l.deudorUid] ?? 0) - l.monto;
        nombres[l.deudorUid] = l.deudorNombre;
      }
    }

    return balances.entries
        .where((e) => e.value.abs() > 0.01)
        .map((e) => BalanceConMiembro(
              uid: e.key,
              nombre: nombres[e.key] ?? e.key,
              monto: e.value,
            ))
        .toList()
      ..sort((a, b) => b.monto.abs().compareTo(a.monto.abs()));
  }

  static double totalDebenA(List<BalanceConMiembro> balances) =>
      balances.where((b) => b.monto > 0).fold(0.0, (s, b) => s + b.monto);

  static double totalDebeA(List<BalanceConMiembro> balances) =>
      balances.where((b) => b.monto < 0).fold(0.0, (s, b) => s + b.monto.abs());

  // ── All-member net balances (for conciliation view) ─────────────────────────

  /// Returns each participant's net position across all gastos and liquidaciones.
  /// Positive saldo → this member is owed money.
  /// Negative saldo → this member owes money.
  static Map<String, ({String nombre, double saldo})> computeNetBalances({
    required List<GastoModel> gastos,
    required List<LiquidacionModel> liquidaciones,
  }) {
    final res = <String, ({String nombre, double saldo})>{};

    void add(String uid, String nombre, double delta) {
      final cur = res[uid]?.saldo ?? 0.0;
      res[uid] = (nombre: nombre, saldo: cur + delta);
    }

    for (final g in gastos) {
      if (g.tipo != TipoMovimiento.gasto) continue;
      // Pagador advances the full amount
      add(g.pagadorUid, g.pagadorNombre, g.monto);
      // Each participant (including pagador) owes their share back
      for (final p in g.participantes) {
        add(p.uid, p.nombre, -p.monto);
      }
    }

    // Liquidaciones settle debts
    for (final l in liquidaciones) {
      add(l.deudorUid, l.deudorNombre, l.monto);   // debtor paid → balance improves
      add(l.acreedorUid, l.acreedorNombre, -l.monto); // creditor received
    }

    return res;
  }

  /// Generates the minimum set of payments to settle all debts in [balances].
  static List<PagoSugerido> computeSettlements(
      Map<String, ({String nombre, double saldo})> balances) {
    // Build mutable amount maps
    final debtAmounts = <String, double>{};
    final creditAmounts = <String, double>{};
    final nombres = <String, String>{};

    for (final e in balances.entries) {
      nombres[e.key] = e.value.nombre;
      if (e.value.saldo < -0.5) {
        debtAmounts[e.key] = -e.value.saldo; // store as positive
      } else if (e.value.saldo > 0.5) {
        creditAmounts[e.key] = e.value.saldo;
      }
    }

    final debtors = debtAmounts.keys.toList()
      ..sort((a, b) => debtAmounts[b]!.compareTo(debtAmounts[a]!));
    final creditors = creditAmounts.keys.toList()
      ..sort((a, b) => creditAmounts[b]!.compareTo(creditAmounts[a]!));

    final settlements = <PagoSugerido>[];
    int di = 0, ci = 0;

    while (di < debtors.length && ci < creditors.length) {
      final d = debtors[di];
      final c = creditors[ci];
      final pay = debtAmounts[d]! < creditAmounts[c]!
          ? debtAmounts[d]!
          : creditAmounts[c]!;

      if (pay > 0.5) {
        settlements.add(PagoSugerido(
          fromUid: d,
          fromNombre: nombres[d]!,
          toUid: c,
          toNombre: nombres[c]!,
          monto: pay,
        ));
      }

      debtAmounts[d] = debtAmounts[d]! - pay;
      creditAmounts[c] = creditAmounts[c]! - pay;

      if (debtAmounts[d]! < 0.5) di++;
      if (creditAmounts[c]! < 0.5) ci++;
    }

    return settlements;
  }
}
