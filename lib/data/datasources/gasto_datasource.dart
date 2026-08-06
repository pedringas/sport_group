import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gasto_model.dart';
import '../models/grupo_gasto_model.dart';

class GastoDatasource {
  final _db = FirebaseFirestore.instance;

  // ── Grupos de gastos ────────────────────────────────────────────────────────

  Stream<List<GrupoGastoModel>> getGruposGasto(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('gruposGasto')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs.map(GrupoGastoModel.fromFirestore).toList());

  Future<String> createGrupoGasto({
    required String grupoId,
    required String nombre,
    String? descripcion,
    required String creadoPorUid,
    required String creadoPorNombre,
  }) async {
    final ref = _db.collection('grupos').doc(grupoId)
        .collection('gruposGasto').doc();
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

  Future<void> cerrarGrupoGasto(String grupoId, String grupoGastoId) =>
      _db.collection('grupos').doc(grupoId).collection('gruposGasto')
          .doc(grupoGastoId)
          .update({'cerrado': true, 'cerradoAt': Timestamp.now()});

  Future<void> reabrirGrupoGasto(String grupoId, String grupoGastoId) =>
      _db.collection('grupos').doc(grupoId).collection('gruposGasto')
          .doc(grupoGastoId)
          .update({'cerrado': false, 'cerradoAt': null});

  Future<void> deleteGrupoGasto(String grupoId, String grupoGastoId) =>
      _db.collection('grupos').doc(grupoId).collection('gruposGasto')
          .doc(grupoGastoId).delete();

  // ── Gastos ──────────────────────────────────────────────────────────────────

  Stream<List<GastoModel>> getGastos(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('gastos')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(GastoModel.fromFirestore).toList());

  Stream<List<GastoModel>> getGastosPorGrupoGasto(
      String grupoId, String? grupoGastoId) {
    final col = _db.collection('grupos').doc(grupoId).collection('gastos');
    final query = grupoGastoId == null
        ? col.where('grupoGastoId', isNull: true)
        : col.where('grupoGastoId', isEqualTo: grupoGastoId);
    return query
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
  }) {
    final fechaTs = Timestamp.fromDate(fecha ?? DateTime.now());
    return _db.collection('grupos').doc(grupoId).collection('gastos').add({
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
  }) =>
      _db.collection('grupos').doc(grupoId).collection('gastos')
          .doc(gastoId).update({
        'titulo': titulo,
        'descripcion': descripcion,
        'monto': monto,
        'participantes': participantes.map((p) => p.toMap()).toList(),
        'categoria': categoria.name,
        'tipo': tipo.name,
        if (grupoGastoId != null) 'grupoGastoId': grupoGastoId,
        if (fecha != null) 'fecha': Timestamp.fromDate(fecha),
      });

  Future<void> deleteGasto(String grupoId, String gastoId) =>
      _db.collection('grupos').doc(grupoId).collection('gastos')
          .doc(gastoId).delete();

  // ── Liquidaciones ───────────────────────────────────────────────────────────

  Stream<List<LiquidacionModel>> getLiquidaciones(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('liquidaciones')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(LiquidacionModel.fromFirestore).toList());

  Future<void> createLiquidacion({
    required String grupoId,
    required String deudorUid,
    required String deudorNombre,
    required String acreedorUid,
    required String acreedorNombre,
    required double monto,
    String? grupoGastoId,
  }) =>
      _db.collection('grupos').doc(grupoId).collection('liquidaciones').add({
        'grupoId': grupoId,
        if (grupoGastoId != null) 'grupoGastoId': grupoGastoId,
        'deudorUid': deudorUid,
        'deudorNombre': deudorNombre,
        'acreedorUid': acreedorUid,
        'acreedorNombre': acreedorNombre,
        'monto': monto,
        'createdAt': Timestamp.now(),
      });

  Future<void> deleteLiquidacion(String grupoId, String liqId) =>
      _db.collection('grupos').doc(grupoId).collection('liquidaciones')
          .doc(liqId).delete();
}
