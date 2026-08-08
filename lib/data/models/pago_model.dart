import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class PagoModel {
  final String id;
  final String grupoId;
  final String cuotaId;
  final String usuarioUid;
  final String usuarioNombre;
  final double montoEsperado;
  final EstadoPago estado;
  final MetodoPago metodo;
  final String? comprobanteUrl;
  final double? montoDetectado;
  final String? ocrRaw;
  final double? ocrConfianza;
  final String? mpPaymentId;
  final String? nota;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PagoModel({
    required this.id,
    required this.grupoId,
    required this.cuotaId,
    required this.usuarioUid,
    required this.usuarioNombre,
    required this.montoEsperado,
    required this.estado,
    required this.metodo,
    this.comprobanteUrl,
    this.montoDetectado,
    this.ocrRaw,
    this.ocrConfianza,
    this.mpPaymentId,
    this.nota,
    required this.createdAt,
    this.updatedAt,
  });

  bool get montosCoinciden {
    if (montoDetectado == null) return false;
    final diff = (montoDetectado! - montoEsperado).abs();
    return diff <= montoEsperado * 0.05;
  }

  /// Tolera documentos incompletos o con enums legacy. `byName` lanzaba ante
  /// cualquier `estado` desconocido y tumbaba la lista entera de pagos —
  /// en release eso se ve como una pantalla gris. `metodo` ya estaba blindado.
  factory PagoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return PagoModel(
      id: doc.id,
      grupoId: d['grupoId']?.toString() ?? '',
      cuotaId: d['cuotaId']?.toString() ?? '',
      usuarioUid: d['usuarioUid']?.toString() ?? '',
      usuarioNombre: d['usuarioNombre']?.toString() ?? '',
      montoEsperado: (d['montoEsperado'] as num?)?.toDouble() ?? 0,
      estado: EstadoPago.values.firstWhere(
        (e) => e.name == d['estado'],
        orElse: () => EstadoPago.pendiente,
      ),
      metodo: MetodoPago.values.firstWhere(
        (m) => m.name == (d['metodo'] ?? 'transferencia'),
        orElse: () => MetodoPago.transferencia, // handles legacy 'manual'/'mercadopago' docs
      ),
      comprobanteUrl: d['comprobanteUrl']?.toString(),
      montoDetectado: (d['montoDetectado'] as num?)?.toDouble(),
      ocrRaw: d['ocrRaw']?.toString(),
      ocrConfianza: (d['ocrConfianza'] as num?)?.toDouble(),
      mpPaymentId: d['mpPaymentId']?.toString(),
      nota: d['nota']?.toString(),
      createdAt: _toDate(d['createdAt']) ?? DateTime.now(),
      updatedAt: _toDate(d['updatedAt']),
    );
  }

  static DateTime? _toDate(dynamic v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  Map<String, dynamic> toMap() => {
        'grupoId': grupoId,
        'cuotaId': cuotaId,
        'usuarioUid': usuarioUid,
        'usuarioNombre': usuarioNombre,
        'montoEsperado': montoEsperado,
        'estado': estado.name,
        'metodo': metodo.name,
        'comprobanteUrl': comprobanteUrl,
        'montoDetectado': montoDetectado,
        'ocrRaw': ocrRaw,
        'ocrConfianza': ocrConfianza,
        'mpPaymentId': mpPaymentId,
        'nota': nota,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      };
}
