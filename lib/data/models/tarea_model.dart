import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

// ── Asignado (member tagged on a task) ───────────────────────────────────────

class AsignadoTarea {
  final String uid;
  final String nombre;
  final String? avatarUrl;

  const AsignadoTarea({
    required this.uid,
    required this.nombre,
    this.avatarUrl,
  });

  factory AsignadoTarea.fromMap(Map<String, dynamic> m) => AsignadoTarea(
        uid: m['uid'] as String? ?? '',
        nombre: m['nombre'] as String? ?? '',
        avatarUrl: m['avatarUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nombre': nombre,
        'avatarUrl': avatarUrl,
      };
}

// ── Tarea ─────────────────────────────────────────────────────────────────────

class TareaModel {
  final String id;
  final String grupoId;
  final String titulo;
  final String? descripcion;
  final String creadoPorUid;
  final String creadoPorNombre;
  final List<AsignadoTarea> asignadosA;
  final TareaEstado estado;
  final DateTime? fechaVencimiento;
  final DateTime createdAt;

  const TareaModel({
    required this.id,
    required this.grupoId,
    required this.titulo,
    this.descripcion,
    required this.creadoPorUid,
    required this.creadoPorNombre,
    required this.asignadosA,
    required this.estado,
    this.fechaVencimiento,
    required this.createdAt,
  });

  bool get vencida =>
      fechaVencimiento != null &&
      fechaVencimiento!.isBefore(DateTime.now()) &&
      estado != TareaEstado.completada &&
      estado != TareaEstado.cancelada;

  bool asignadoA(String uid) => asignadosA.any((a) => a.uid == uid);

  factory TareaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime? fechaVenc;
    if (d['fechaVencimiento'] != null) {
      fechaVenc = (d['fechaVencimiento'] as Timestamp).toDate();
    }
    return TareaModel(
      id: doc.id,
      grupoId: d['grupoId'] as String? ?? '',
      titulo: d['titulo'] as String? ?? '',
      descripcion: d['descripcion'] as String?,
      creadoPorUid: d['creadoPorUid'] as String? ?? '',
      creadoPorNombre: d['creadoPorNombre'] as String? ?? '',
      asignadosA: (d['asignadosA'] as List<dynamic>? ?? [])
          .map((e) => AsignadoTarea.fromMap(e as Map<String, dynamic>))
          .toList(),
      estado: TareaEstado.values.byName(d['estado'] as String? ?? 'pendiente'),
      fechaVencimiento: fechaVenc,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'titulo': titulo,
        'descripcion': descripcion,
        'creadoPorUid': creadoPorUid,
        'creadoPorNombre': creadoPorNombre,
        'asignadosA': asignadosA.map((a) => a.toMap()).toList(),
        'estado': estado.name,
        if (fechaVencimiento != null)
          'fechaVencimiento': Timestamp.fromDate(fechaVencimiento!),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
