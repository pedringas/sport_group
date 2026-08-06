import 'package:cloud_firestore/cloud_firestore.dart';

// ── Tipo de movimiento ────────────────────────────────────────────────────────

enum TipoMovimiento { gasto, ingreso }

extension TipoMovimientoX on TipoMovimiento {
  String get label => this == TipoMovimiento.gasto ? 'Gasto' : 'Ingreso';
  String get emoji => this == TipoMovimiento.gasto ? '📤' : '📥';
}

// ── Categorías de gasto ────────────────────────────────────────────────────────

enum CategoriaGasto {
  comida,
  transporte,
  bebida,
  alojamiento,
  equipamiento,
  entretenimiento,
  servicios,
  otro,
}

extension CategoriaGastoX on CategoriaGasto {
  String get label => switch (this) {
        CategoriaGasto.comida => 'Comida',
        CategoriaGasto.transporte => 'Transporte',
        CategoriaGasto.bebida => 'Bebida',
        CategoriaGasto.alojamiento => 'Alojamiento',
        CategoriaGasto.equipamiento => 'Equipamiento',
        CategoriaGasto.entretenimiento => 'Entretenimiento',
        CategoriaGasto.servicios => 'Servicios',
        CategoriaGasto.otro => 'Varios',
      };

  String get emoji => switch (this) {
        CategoriaGasto.comida => '🍕',
        CategoriaGasto.transporte => '🚗',
        CategoriaGasto.bebida => '🥤',
        CategoriaGasto.alojamiento => '🏨',
        CategoriaGasto.equipamiento => '⚽',
        CategoriaGasto.entretenimiento => '🎉',
        CategoriaGasto.servicios => '🔧',
        CategoriaGasto.otro => '📌',
      };
}

// ── Participante en un gasto ──────────────────────────────────────────────────

class ParticipanteGasto {
  final String uid;
  final String nombre;

  /// Share of the total expense this person owes the payer.
  final double monto;

  const ParticipanteGasto({
    required this.uid,
    required this.nombre,
    required this.monto,
  });

  factory ParticipanteGasto.fromMap(Map<String, dynamic> m) =>
      ParticipanteGasto(
        uid: m['uid'] as String? ?? '',
        nombre: m['nombre'] as String? ?? '',
        monto: (m['monto'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() =>
      {'uid': uid, 'nombre': nombre, 'monto': monto};
}

// ── Gasto ─────────────────────────────────────────────────────────────────────

class GastoModel {
  final String id;
  final String grupoId;
  final String? grupoGastoId;
  final String pagadorUid;
  final String pagadorNombre;
  final String titulo;
  final String? descripcion;
  final double monto;
  final List<ParticipanteGasto> participantes;
  final CategoriaGasto categoria;
  final TipoMovimiento tipo;
  final DateTime createdAt;
  final DateTime fecha; // user-chosen date (falls back to createdAt for old records)

  const GastoModel({
    required this.id,
    required this.grupoId,
    this.grupoGastoId,
    required this.pagadorUid,
    required this.pagadorNombre,
    required this.titulo,
    this.descripcion,
    required this.monto,
    required this.participantes,
    required this.categoria,
    this.tipo = TipoMovimiento.gasto,
    required this.createdAt,
    DateTime? fecha,
  })  : fecha = fecha ?? createdAt,
        assert(monto > 0, 'GastoModel.monto debe ser mayor a 0'),
        assert(titulo.length > 0, 'GastoModel.titulo no puede estar vacío');

  bool get esIngreso => tipo == TipoMovimiento.ingreso;

  /// What a given user owes the payer (0 if they are the payer or ingreso).
  double deudaDe(String uid) {
    if (esIngreso || uid == pagadorUid) return 0;
    final p = participantes.where((p) => p.uid == uid).firstOrNull;
    return p?.monto ?? 0;
  }

  /// Sum owed to payer from non-payers (only for gastos).
  double get totalDeuda => esIngreso
      ? 0
      : participantes
          .where((p) => p.uid != pagadorUid)
          .fold(0.0, (sum, p) => sum + p.monto);

  factory GastoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GastoModel(
      id: doc.id,
      grupoId: d['grupoId'] as String? ?? '',
      grupoGastoId: d['grupoGastoId'] as String?,
      pagadorUid: d['pagadorUid'] as String? ?? '',
      pagadorNombre: d['pagadorNombre'] as String? ?? '',
      titulo: d['titulo'] as String? ?? '',
      descripcion: d['descripcion'] as String?,
      monto: (d['monto'] as num).toDouble(),
      participantes: (d['participantes'] as List<dynamic>? ?? [])
          .map((e) => ParticipanteGasto.fromMap(e as Map<String, dynamic>))
          .toList(),
      categoria: CategoriaGasto.values
          .byName(d['categoria'] as String? ?? 'otro'),
      tipo: TipoMovimiento.values
          .byName(d['tipo'] as String? ?? 'gasto'),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      fecha: d['fecha'] != null
          ? (d['fecha'] as Timestamp).toDate()
          : (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
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
        'createdAt': Timestamp.fromDate(createdAt),
        'fecha': Timestamp.fromDate(fecha),
      };
}

// ── Liquidación (settlement between two members) ──────────────────────────────

class LiquidacionModel {
  final String id;
  final String grupoId;
  final String? grupoGastoId;
  final String deudorUid;
  final String deudorNombre;
  final String acreedorUid;
  final String acreedorNombre;
  final double monto;
  final DateTime createdAt;

  const LiquidacionModel({
    required this.id,
    required this.grupoId,
    this.grupoGastoId,
    required this.deudorUid,
    required this.deudorNombre,
    required this.acreedorUid,
    required this.acreedorNombre,
    required this.monto,
    required this.createdAt,
  });

  factory LiquidacionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LiquidacionModel(
      id: doc.id,
      grupoId: d['grupoId'] as String? ?? '',
      grupoGastoId: d['grupoGastoId'] as String?,
      deudorUid: d['deudorUid'] as String? ?? '',
      deudorNombre: d['deudorNombre'] as String? ?? '',
      acreedorUid: d['acreedorUid'] as String? ?? '',
      acreedorNombre: d['acreedorNombre'] as String? ?? '',
      monto: (d['monto'] as num).toDouble(),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        if (grupoGastoId != null) 'grupoGastoId': grupoGastoId,
        'deudorUid': deudorUid,
        'deudorNombre': deudorNombre,
        'acreedorUid': acreedorUid,
        'acreedorNombre': acreedorNombre,
        'monto': monto,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ── Balance (computed, not stored) ────────────────────────────────────────────

/// Net balance between the current user and another member.
/// [monto] > 0 → the other person owes current user.
/// [monto] < 0 → current user owes the other person.
class BalanceConMiembro {
  final String uid;
  final String nombre;
  final double monto;

  const BalanceConMiembro({
    required this.uid,
    required this.nombre,
    required this.monto,
  });
}

// ── Pago sugerido (settlement recommendation) ─────────────────────────────────

/// Represents a single suggested payment to settle debts within a group.
class PagoSugerido {
  final String fromUid;
  final String fromNombre;
  final String toUid;
  final String toNombre;
  final double monto;

  const PagoSugerido({
    required this.fromUid,
    required this.fromNombre,
    required this.toUid,
    required this.toNombre,
    required this.monto,
  });
}
