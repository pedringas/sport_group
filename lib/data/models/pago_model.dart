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

  factory PagoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PagoModel(
      id: doc.id,
      grupoId: d['grupoId'] ?? '',
      cuotaId: d['cuotaId'] ?? '',
      usuarioUid: d['usuarioUid'] ?? '',
      usuarioNombre: d['usuarioNombre'] ?? '',
      montoEsperado: (d['montoEsperado'] as num).toDouble(),
      estado: EstadoPago.values.byName(d['estado'] ?? 'pendiente'),
      metodo: MetodoPago.values.firstWhere(
        (m) => m.name == (d['metodo'] ?? 'transferencia'),
        orElse: () => MetodoPago.transferencia, // handles legacy 'manual'/'mercadopago' docs
      ),
      comprobanteUrl: d['comprobanteUrl'],
      montoDetectado: d['montoDetectado'] != null
          ? (d['montoDetectado'] as num).toDouble()
          : null,
      ocrRaw: d['ocrRaw'],
      ocrConfianza: d['ocrConfianza'] != null
          ? (d['ocrConfianza'] as num).toDouble()
          : null,
      mpPaymentId: d['mpPaymentId'],
      nota: d['nota'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

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
