import 'package:cloud_firestore/cloud_firestore.dart';

class CuotaGrupoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final double montoMensual;
  final int diaVencimiento;
  final List<String> miembrosUids;
  final DateTime createdAt;

  const CuotaGrupoModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.montoMensual,
    required this.diaVencimiento,
    required this.miembrosUids,
    required this.createdAt,
  });

  factory CuotaGrupoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CuotaGrupoModel(
      id: doc.id,
      nombre: d['nombre'] as String? ?? '',
      descripcion: d['descripcion'] as String? ?? '',
      montoMensual: (d['montoMensual'] as num?)?.toDouble() ?? 0,
      diaVencimiento: (d['diaVencimiento'] as num?)?.toInt() ?? 10,
      miembrosUids: List<String>.from(d['miembrosUids'] ?? []),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'montoMensual': montoMensual,
        'diaVencimiento': diaVencimiento,
        'miembrosUids': miembrosUids,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  CuotaGrupoModel copyWith({
    String? nombre,
    String? descripcion,
    double? montoMensual,
    int? diaVencimiento,
    List<String>? miembrosUids,
  }) =>
      CuotaGrupoModel(
        id: id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        montoMensual: montoMensual ?? this.montoMensual,
        diaVencimiento: diaVencimiento ?? this.diaVencimiento,
        miembrosUids: miembrosUids ?? this.miembrosUids,
        createdAt: createdAt,
      );

  // Compute vencimiento date for a given year/month
  DateTime vencimientoFor(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = diaVencimiento.clamp(1, lastDay);
    return DateTime(year, month, day);
  }
}
