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

  /// Tolera documentos incompletos: un solo doc con un campo faltante o de otro
  /// tipo hacía explotar el `.map()` de toda la lista de cuotas, y en release
  /// eso se veía como una pantalla gris sin contenido.
  factory CuotaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};

    final createdAt = _toDate(d['createdAt']) ?? DateTime.now();

    return CuotaModel(
      id: doc.id,
      grupoId: d['grupoId']?.toString() ?? '',
      titulo: d['titulo']?.toString() ?? 'Cuota sin título',
      descripcion: d['descripcion']?.toString(),
      monto: (d['monto'] as num?)?.toDouble() ?? 0,
      vencimiento: _toDate(d['vencimiento']) ?? createdAt,
      activa: d['activa'] as bool? ?? true,
      createdAt: createdAt,
      esRecurrente: d['esRecurrente'] as bool? ?? false,
      frecuencia: _toFrecuencia(d['frecuencia']),
      totalCuotas: (d['totalCuotas'] as num?)?.toInt(),
      numeroCuota: (d['numeroCuota'] as num?)?.toInt(),
      serieId: d['serieId']?.toString(),
      miembrosUids: _toStringList(d['miembrosUids']),
      excluidosUids: _toStringList(d['excluidosUids']),
    );
  }

  static DateTime? _toDate(dynamic v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  static FrecuenciaCuota? _toFrecuencia(dynamic v) {
    if (v == null) return null;
    final name = v.toString();
    for (final f in FrecuenciaCuota.values) {
      if (f.name == name) return f;
    }
    return null;
  }

  static List<String>? _toStringList(dynamic v) => v is List
      ? v.map((e) => e.toString()).toList()
      : null;

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
