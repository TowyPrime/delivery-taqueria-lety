import 'package:cloud_firestore/cloud_firestore.dart';

/// Reglas del formulario de reclamación (las usa la UI y el servicio).
class ClaimRules {
  ClaimRules._();

  static const int minReasonLength = 10;
  static const int maxReasonLength = 500;
  static const int minPhotos = 1;
  static const int maxPhotos = 3;
}

enum ClaimType {
  devolucion('devolucion', 'Devolución'),
  cancelacion('cancelacion', 'Cancelación'),
  queja('queja', 'Queja'),
  otro('otro', 'Otro');

  const ClaimType(this.value, this.label);

  /// Valor que se guarda en Firestore.
  final String value;
  final String label;

  static ClaimType fromValue(String? v) => ClaimType.values.firstWhere(
    (t) => t.value == v,
    orElse: () => ClaimType.otro,
  );
}

enum ClaimStatus {
  abierta('abierta', 'Abierta'),
  enRevision('en_revision', 'En revisión'),
  resuelta('resuelta', 'Resuelta'),
  rechazada('rechazada', 'Rechazada');

  const ClaimStatus(this.value, this.label);

  /// Valor que se guarda en Firestore.
  final String value;
  final String label;

  /// Una reclamación sigue "viva" mientras no esté resuelta ni rechazada.
  bool get isOpen => this == abierta || this == enRevision;

  static ClaimStatus fromValue(String? v) => ClaimStatus.values.firstWhere(
    (s) => s.value == v,
    orElse: () => ClaimStatus.abierta,
  );
}

class ClaimModel {
  final String id;
  final String orderId;
  final String userId;
  final String userName;
  final ClaimType type;
  final String reason;
  final ClaimStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double orderTotal;
  final String orderStatusAtRequest;
  final List<String> evidenceUrls;
  final String? contactPhone;

  // Los llena el negocio al resolver.
  final String? resolution;
  final double? refundAmount;
  final DateTime? resolvedAt;

  const ClaimModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.type,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.userName = '',
    this.updatedAt,
    this.orderTotal = 0,
    this.orderStatusAtRequest = '',
    this.evidenceUrls = const [],
    this.contactPhone,
    this.resolution,
    this.refundAmount,
    this.resolvedAt,
  });

  /// Folio corto para mostrar al cliente (igual que los pedidos).
  String get folio => id.substring(0, id.length < 6 ? id.length : 6).toUpperCase();

  factory ClaimModel.fromFirestore(DocumentSnapshot doc) =>
      ClaimModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);

  factory ClaimModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? date(Object? v) => (v as Timestamp?)?.toDate();

    String? text(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return ClaimModel(
      id: id,
      orderId: data['orderId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      type: ClaimType.fromValue(data['type'] as String?),
      reason: data['reason'] ?? '',
      status: ClaimStatus.fromValue(data['status'] as String?),
      // createdAt es null un instante, mientras el servidor confirma la marca.
      createdAt: date(data['createdAt']) ?? DateTime.now(),
      updatedAt: date(data['updatedAt']),
      orderTotal: (data['orderTotal'] as num?)?.toDouble() ?? 0,
      orderStatusAtRequest: data['orderStatusAtRequest'] ?? '',
      evidenceUrls: List<String>.from(data['evidenceUrls'] ?? const []),
      contactPhone: text(data['contactPhone']),
      resolution: text(data['resolution']),
      refundAmount: (data['refundAmount'] as num?)?.toDouble(),
      resolvedAt: date(data['resolvedAt']),
    );
  }
}
