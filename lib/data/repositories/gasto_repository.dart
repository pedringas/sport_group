import '../datasources/gasto_datasource.dart';
import '../models/gasto_model.dart';
import '../models/grupo_gasto_model.dart';

class GastoRepository {
  final GastoDatasource _ds;
  GastoRepository([GastoDatasource? ds]) : _ds = ds ?? GastoDatasource();

  // ── Grupos de gastos ────────────────────────────────────────────────────────

  Stream<List<GrupoGastoModel>> getGruposGasto(String grupoId) =>
      _ds.getGruposGasto(grupoId);

  Future<String> createGrupoGasto({
    required String grupoId,
    required String nombre,
    String? descripcion,
    required String creadoPorUid,
    required String creadoPorNombre,
  }) =>
      _ds.createGrupoGasto(
        grupoId: grupoId,
        nombre: nombre,
        descripcion: descripcion,
        creadoPorUid: creadoPorUid,
        creadoPorNombre: creadoPorNombre,
      );

  Future<void> cerrarGrupoGasto(String grupoId, String grupoGastoId) =>
      _ds.cerrarGrupoGasto(grupoId, grupoGastoId);

  Future<void> reabrirGrupoGasto(String grupoId, String grupoGastoId) =>
      _ds.reabrirGrupoGasto(grupoId, grupoGastoId);

  Future<void> deleteGrupoGasto(String grupoId, String grupoGastoId) =>
      _ds.deleteGrupoGasto(grupoId, grupoGastoId);

  // ── Gastos ──────────────────────────────────────────────────────────────────

  Stream<List<GastoModel>> getGastos(String grupoId) =>
      _ds.getGastos(grupoId);

  Stream<List<GastoModel>> getGastosPorGrupoGasto(
          String grupoId, String? grupoGastoId) =>
      _ds.getGastosPorGrupoGasto(grupoId, grupoGastoId);

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
  }) =>
      _ds.createGasto(
        grupoId: grupoId,
        pagadorUid: pagadorUid,
        pagadorNombre: pagadorNombre,
        titulo: titulo,
        descripcion: descripcion,
        monto: monto,
        participantes: participantes,
        categoria: categoria,
        tipo: tipo,
        grupoGastoId: grupoGastoId,
        fecha: fecha,
      );

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
  }) =>
      _ds.updateGasto(
        grupoId: grupoId,
        gastoId: gastoId,
        titulo: titulo,
        descripcion: descripcion,
        monto: monto,
        participantes: participantes,
        categoria: categoria,
        tipo: tipo,
        grupoGastoId: grupoGastoId,
        fecha: fecha,
      );

  Future<void> deleteGasto(String grupoId, String gastoId) =>
      _ds.deleteGasto(grupoId, gastoId);

  // ── Liquidaciones ───────────────────────────────────────────────────────────

  Stream<List<LiquidacionModel>> getLiquidaciones(String grupoId) =>
      _ds.getLiquidaciones(grupoId);

  Future<void> createLiquidacion({
    required String grupoId,
    required String deudorUid,
    required String deudorNombre,
    required String acreedorUid,
    required String acreedorNombre,
    required double monto,
    String? grupoGastoId,
  }) =>
      _ds.createLiquidacion(
        grupoId: grupoId,
        deudorUid: deudorUid,
        deudorNombre: deudorNombre,
        acreedorUid: acreedorUid,
        acreedorNombre: acreedorNombre,
        monto: monto,
        grupoGastoId: grupoGastoId,
      );

  Future<void> deleteLiquidacion(String grupoId, String liqId) =>
      _ds.deleteLiquidacion(grupoId, liqId);

  // ── Balance computation ─────────────────────────────────────────────────────

  static List<BalanceConMiembro> computeBalances({
    required String currentUid,
    required List<GastoModel> gastos,
    required List<LiquidacionModel> liquidaciones,
  }) {
    final Map<String, double> balances = {};
    final Map<String, String> nombres = {};

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
        balances[l.acreedorUid] = (balances[l.acreedorUid] ?? 0) + l.monto;
        nombres[l.acreedorUid] = l.acreedorNombre;
      } else if (l.acreedorUid == currentUid) {
        balances[l.deudorUid] = (balances[l.deudorUid] ?? 0) - l.monto;
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
      add(g.pagadorUid, g.pagadorNombre, g.monto);
      for (final p in g.participantes) {
        add(p.uid, p.nombre, -p.monto);
      }
    }

    for (final l in liquidaciones) {
      add(l.deudorUid, l.deudorNombre, l.monto);
      add(l.acreedorUid, l.acreedorNombre, -l.monto);
    }

    return res;
  }

  static List<PagoSugerido> computeSettlements(
      Map<String, ({String nombre, double saldo})> balances) {
    final debtAmounts = <String, double>{};
    final creditAmounts = <String, double>{};
    final nombres = <String, String>{};

    for (final e in balances.entries) {
      nombres[e.key] = e.value.nombre;
      if (e.value.saldo < -0.5) {
        debtAmounts[e.key] = -e.value.saldo;
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
