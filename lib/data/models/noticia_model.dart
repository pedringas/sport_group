import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class NoticiaModel {
  final String id;
  final String grupoId;
  final String autorUid;
  final String autorNombre;
  final String titulo;
  final String contenido;
  final String? imagenUrl;
  final List<String> likes;
  final bool fijada;
  final bool tieneListado; // attendance sign-up list
  final NoticiaCategoria categoria;
  final DateTime createdAt;
  final List<MencionadoItem> mencionados;
  final DateTime? fechaCaducidad;
  final DateTime? fechaEvento;

  const NoticiaModel({
    required this.id,
    required this.grupoId,
    required this.autorUid,
    required this.autorNombre,
    required this.titulo,
    required this.contenido,
    this.imagenUrl,
    required this.likes,
    this.fijada = false,
    this.tieneListado = false,
    this.categoria = NoticiaCategoria.general,
    required this.createdAt,
    this.mencionados = const [],
    this.fechaCaducidad,
    this.fechaEvento,
  });

  bool likedBy(String uid) => likes.contains(uid);
  int get likesCount => likes.length;
  bool get caducada =>
      fechaCaducidad != null && fechaCaducidad!.isBefore(DateTime.now());

  factory NoticiaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NoticiaModel(
      id: doc.id,
      grupoId: d['grupoId'] ?? '',
      autorUid: d['autorUid'] ?? '',
      autorNombre: d['autorNombre'] ?? '',
      titulo: d['titulo'] ?? '',
      contenido: d['contenido'] ?? '',
      imagenUrl: d['imagenUrl'],
      likes: List<String>.from(d['likes'] ?? []),
      fijada: d['fijada'] ?? false,
      tieneListado: d['tieneListado'] ?? false,
      categoria: NoticiaCategoria.values.byName(
          d['categoria'] as String? ?? 'general'),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      mencionados: (d['mencionados'] as List<dynamic>? ?? [])
          .map((e) => MencionadoItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      fechaCaducidad: d['fechaCaducidad'] != null
          ? (d['fechaCaducidad'] as Timestamp).toDate()
          : null,
      fechaEvento: d['fechaEvento'] != null
          ? (d['fechaEvento'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'autorUid': autorUid,
        'autorNombre': autorNombre,
        'titulo': titulo,
        'contenido': contenido,
        'imagenUrl': imagenUrl,
        'likes': likes,
        'fijada': fijada,
        'tieneListado': tieneListado,
        'categoria': categoria.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'mencionados': mencionados.map((m) => m.toMap()).toList(),
        'fechaCaducidad': fechaCaducidad != null
            ? Timestamp.fromDate(fechaCaducidad!)
            : null,
        'fechaEvento': fechaEvento != null
            ? Timestamp.fromDate(fechaEvento!)
            : null,
      };
}

// ── Mencionado item (tagged members) ────────────────────────────────────────

class MencionadoItem {
  final String uid;
  final String nombre;

  const MencionadoItem({required this.uid, required this.nombre});

  factory MencionadoItem.fromMap(Map<String, dynamic> d) => MencionadoItem(
        uid: d['uid'] as String? ?? '',
        nombre: d['nombre'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'uid': uid, 'nombre': nombre};
}

// ── Comentario item ──────────────────────────────────────────────────────────

class ComentarioModel {
  final String id;
  final String uid;
  final String nombre;
  final String? avatarUrl;
  final String texto;
  final DateTime createdAt;

  const ComentarioModel({
    required this.id,
    required this.uid,
    required this.nombre,
    this.avatarUrl,
    required this.texto,
    required this.createdAt,
  });

  factory ComentarioModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ComentarioModel(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      nombre: d['nombre'] as String? ?? '',
      avatarUrl: d['avatarUrl'] as String?,
      texto: d['texto'] as String? ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

// ── Lectura item (who read the noticia) ──────────────────────────────────────

class LecturaItem {
  final String uid;
  final String nombre;
  final DateTime timestamp;

  const LecturaItem({
    required this.uid,
    required this.nombre,
    required this.timestamp,
  });

  factory LecturaItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LecturaItem(
      uid: doc.id,
      nombre: d['nombre'] ?? '',
      timestamp: (d['timestamp'] as Timestamp).toDate(),
    );
  }
}

// ── Asistencia item (who is going / not going) ───────────────────────────────

class AsistenciaItem {
  final String uid;
  final String nombre;
  final String? avatarUrl;
  final String estado; // 'va' | 'no_va'
  final DateTime timestamp;

  const AsistenciaItem({
    required this.uid,
    required this.nombre,
    this.avatarUrl,
    required this.estado,
    required this.timestamp,
  });

  bool get va => estado == 'va';

  factory AsistenciaItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AsistenciaItem(
      uid: doc.id,
      nombre: d['nombre'] ?? '',
      avatarUrl: d['avatarUrl'],
      estado: d['estado'] ?? 'va',
      timestamp: (d['timestamp'] as Timestamp).toDate(),
    );
  }
}
