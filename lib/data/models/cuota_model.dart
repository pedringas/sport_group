import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class CuotaModel {
  final String id;
  final String grupoId;
  final String titulo;
  final String? descripcion;
  final double monto;
  final DateTime vencimiento;
  final bool activa;
  final DateTime createdAt;

  // ── Recurrence fields ──────────────────────────────────────────────────────
  /// true if this cuota is part of a recurring series
  final bool esRecurrente;
  /// Recurrence frequency (only set if esRecurrente == true)
  final FrecuenciaCuota? frecuencia;
  /// Total number of cuotas in the series (e.g. 12 for a year of monthly fees)
  final int? totalCuotas;
  /// This cuota's position in the series (1-based)
  final int? numeroCuota;
  /// ID shared by all cuotas in the same series
  final String? serieId;
  /// If set, only these UIDs are charged. null = everyone.
  final List<String>? miembrosUids;
  /// If set, these UIDs are excluded from the cuota.
  final List<String>? excluidosUids;

  const CuotaModel({
    required this.id,
    required this.grupoId,
    required this.titulo,
    this.descripcion,
    required this.monto,
    required this.vencimiento,
    required this.activa,
    required this.createdAt,
    this.esRecurrente = false,
    this.frecuencia,
    this.totalCuotas,
    this.numeroCuota,
    this.serieId,
    this.miembrosUids,
    this.excluidosUids,
  });

  factory CuotaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CuotaModel(
      id: doc.id,
      grupoId: d['grupoId'] ?? '',
      titulo: d['titulo'] ?? '',
      descripcion: d['descripcion'],
      monto: (d['monto'] as num).toDouble(),
      vencimiento: (d['vencimiento'] as Timestamp).toDate(),
      activa: d['activa'] ?? true,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      esRecurrente: d['esRecurrente'] ?? false,
      frecuencia: d['frecuencia'] != null
          ? FrecuenciaCuota.values.byName(d['frecuencia'] as String)
          : null,
      totalCuotas: d['totalCuotas'] as int?,
      numeroCuota: d['numeroCuota'] as int?,
      serieId: d['serieId'] as String?,
      miembrosUids: (d['miembrosUids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      excluidosUids: (d['excluidosUids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'titulo': titulo,
        'descripcion': descripcion,
        'monto': monto,
        'vencimiento': Timestamp.fromDate(vencimiento),
        'activa': activa,
        'createdAt': Timestamp.fromDate(createdAt),
        'esRecurrente': esRecurrente,
        if (frecuencia != null) 'frecuencia': frecuencia!.name,
        if (totalCuotas != null) 'totalCuotas': totalCuotas,
        if (numeroCuota != null) 'numeroCuota': numeroCuota,
        if (serieId != null) 'serieId': serieId,
        if (miembrosUids != null) 'miembrosUids': miembrosUids,
        if (excluidosUids != null) 'excluidosUids': excluidosUids,
      };

  /// Label shown in the list (e.g. "Cuota marzo 2025 (3/12)")
  String get tituloConNumero => esRecurrente && numeroCuota != null && totalCuotas != null
      ? '$titulo ($numeroCuota/$totalCuotas)'
      : titulo;
}
