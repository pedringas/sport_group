import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class CampanaModel {
  final String id;
  final String grupoId;
  final String titulo;
  final String? descripcion;
  final double objetivo;      // target amount
  final double montoActual;   // sum of approved aportes
  final EstadoCampana estado;
  final DateTime? fechaLimite;
  final String? imagenUrl;
  final String creadoPor;     // uid
  final DateTime createdAt;

  const CampanaModel({
    required this.id,
    required this.grupoId,
    required this.titulo,
    this.descripcion,
    required this.objetivo,
    required this.montoActual,
    required this.estado,
    this.fechaLimite,
    this.imagenUrl,
    required this.creadoPor,
    required this.createdAt,
  });

  double get porcentaje => objetivo > 0 ? (montoActual / objetivo).clamp(0.0, 1.0) : 0.0;
  double get faltante => (objetivo - montoActual).clamp(0.0, double.infinity);
  bool get completada => montoActual >= objetivo;

  factory CampanaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CampanaModel(
      id: doc.id,
      grupoId: d['grupoId'] ?? '',
      titulo: d['titulo'] ?? '',
      descripcion: d['descripcion'],
      objetivo: (d['objetivo'] as num).toDouble(),
      montoActual: (d['montoActual'] as num? ?? 0).toDouble(),
      estado: EstadoCampana.values.byName(d['estado'] ?? 'activa'),
      fechaLimite: d['fechaLimite'] != null
          ? (d['fechaLimite'] as Timestamp).toDate()
          : null,
      imagenUrl: d['imagenUrl'],
      creadoPor: d['creadoPor'] ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'titulo': titulo,
        'descripcion': descripcion,
        'objetivo': objetivo,
        'montoActual': montoActual,
        'estado': estado.name,
        if (fechaLimite != null) 'fechaLimite': Timestamp.fromDate(fechaLimite!),
        'imagenUrl': imagenUrl,
        'creadoPor': creadoPor,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ── Aporte ────────────────────────────────────────────────────────────────────

class AporteModel {
  final String id;
  final String campanaId;
  final String grupoId;
  final String usuarioUid;
  final String usuarioNombre;
  final double monto;
  final String? mensaje;
  final String? comprobanteUrl;
  final EstadoAporte estado;
  final String? metodo;          // 'efectivo' | 'transferencia' | null (legacy)
  final double? montoDeclarado;  // monto declarado al momento del registro
  final DateTime createdAt;

  const AporteModel({
    required this.id,
    required this.campanaId,
    required this.grupoId,
    required this.usuarioUid,
    required this.usuarioNombre,
    required this.monto,
    this.mensaje,
    this.comprobanteUrl,
    required this.estado,
    this.metodo,
    this.montoDeclarado,
    required this.createdAt,
  });

  factory AporteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AporteModel(
      id: doc.id,
      campanaId: d['campanaId'] ?? '',
      grupoId: d['grupoId'] ?? '',
      usuarioUid: d['usuarioUid'] ?? '',
      usuarioNombre: d['usuarioNombre'] ?? '',
      monto: (d['monto'] as num).toDouble(),
      mensaje: d['mensaje'],
      comprobanteUrl: d['comprobanteUrl'],
      estado: EstadoAporte.values.byName(d['estado'] ?? 'pendiente'),
      metodo: d['metodo'] as String?,
      montoDeclarado: d['montoDeclarado'] != null
          ? (d['montoDeclarado'] as num).toDouble()
          : null,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'campanaId': campanaId,
        'grupoId': grupoId,
        'usuarioUid': usuarioUid,
        'usuarioNombre': usuarioNombre,
        'monto': monto,
        'mensaje': mensaje,
        'comprobanteUrl': comprobanteUrl,
        'estado': estado.name,
        if (metodo != null) 'metodo': metodo,
        if (montoDeclarado != null) 'montoDeclarado': montoDeclarado,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
