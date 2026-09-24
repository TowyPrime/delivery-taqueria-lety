import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/models/claim_model.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Error con un mensaje apto para mostrar al usuario.
class ClaimException implements Exception {
  final String message;
  const ClaimException(this.message);

  @override
  String toString() => message;
}

/// Sube las fotos de evidencia y devuelve sus URLs (en el mismo orden).
typedef EvidenceUploader =
    Future<List<String>> Function({
      required String userId,
      required String claimId,
      required List<String> paths,
    });

class ClaimService {
  ClaimService({FirebaseFirestore? firestore, EvidenceUploader? uploader})
    : _firestore = firestore,
      _uploader = uploader ?? _uploadToStorage;

  // Se resuelve al usarse, para poder construir el servicio sin Firebase.
  final FirebaseFirestore? _firestore;
  final EvidenceUploader _uploader;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Crea la reclamación y marca el pedido con `hasClaim` y `claimId`.
  /// Devuelve el id de la reclamación.
  ///
  /// Reglas: motivo con al menos [ClaimRules.minReasonLength] caracteres y
  /// entre [ClaimRules.minPhotos] y [ClaimRules.maxPhotos] fotos.
  Future<String> createClaim({
    required String orderId,
    required String userId,
    required String userName,
    required ClaimType type,
    required String reason,
    required List<String> evidencePaths,
    required double orderTotal,
    required String orderStatus,
    String? contactPhone,
  }) async {
    final text = reason.trim();
    if (text.length < ClaimRules.minReasonLength) {
      throw const ClaimException(
        'Explica el motivo con al menos ${ClaimRules.minReasonLength} caracteres.',
      );
    }
    if (text.length > ClaimRules.maxReasonLength) {
      throw const ClaimException(
        'La explicación no puede pasar de ${ClaimRules.maxReasonLength} caracteres.',
      );
    }
    if (evidencePaths.length < ClaimRules.minPhotos) {
      throw const ClaimException('Agrega al menos una foto como evidencia.');
    }
    if (evidencePaths.length > ClaimRules.maxPhotos) {
      throw const ClaimException(
        'Puedes adjuntar máximo ${ClaimRules.maxPhotos} fotos.',
      );
    }

    final orderRef = _db.collection('orders').doc(orderId);

    // Falla rápido (antes de subir fotos) si el pedido no es válido.
    _assertOrderCanBeClaimed(await orderRef.get(), userId);

    final claimRef = _db.collection('claims').doc();

    final List<String> urls;
    try {
      urls = await _uploader(
        userId: userId,
        claimId: claimRef.id,
        paths: evidencePaths,
      );
    } catch (_) {
      throw const ClaimException(
        'No pudimos subir tus fotos. Revisa tu conexión e inténtalo de nuevo.',
      );
    }

    try {
      // La transacción garantiza que reclamación y pedido se actualicen juntos
      // y que dos envíos simultáneos no creen dos reclamaciones.
      await _db.runTransaction((tx) async {
        _assertOrderCanBeClaimed(await tx.get(orderRef), userId);

        tx.set(claimRef, {
          'orderId': orderId,
          'userId': userId,
          'userName': userName,
          'type': type.value,
          'reason': text,
          'status': ClaimStatus.abierta.value,
          'evidenceUrls': urls,
          'orderTotal': orderTotal,
          'orderStatusAtRequest': orderStatus,
          if (contactPhone != null && contactPhone.trim().isNotEmpty)
            'contactPhone': contactPhone.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(orderRef, {
          'hasClaim': true,
          'claimId': claimRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ClaimException {
      rethrow;
    } catch (_) {
      throw const ClaimException(
        'No pudimos registrar tu reclamación. Inténtalo de nuevo.',
      );
    }

    return claimRef.id;
  }

  void _assertOrderCanBeClaimed(DocumentSnapshot order, String userId) {
    if (!order.exists) {
      throw const ClaimException('El pedido ya no existe.');
    }
    final data = order.data() as Map<String, dynamic>;
    if (data['userId'] != userId) {
      throw const ClaimException('Este pedido no pertenece a tu cuenta.');
    }
    final hasClaim =
        data['hasClaim'] == true ||
        ((data['claimId'] as String?)?.isNotEmpty ?? false);
    if (hasClaim) {
      throw const ClaimException('Este pedido ya tiene una reclamación.');
    }
  }

  /// Reclamaciones más recientes del usuario (para el asistente).
  Future<List<ClaimModel>> fetchUserClaims(
    String userId, {
    int limit = 5,
  }) async {
    final snapshot = await _db
        .collection('claims')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(ClaimModel.fromFirestore).toList();
  }

  /// Sigue una reclamación en tiempo real (null si no existe).
  Stream<ClaimModel?> streamClaim(String claimId) {
    return _db
        .collection('claims')
        .doc(claimId)
        .snapshots()
        .map((s) => s.exists ? ClaimModel.fromFirestore(s) : null);
  }
}

Future<List<String>> _uploadToStorage({
  required String userId,
  required String claimId,
  required List<String> paths,
}) async {
  final storage = FirebaseStorage.instance;
  final urls = <String>[];
  for (var i = 0; i < paths.length; i++) {
    final ref = storage.ref('claims/$userId/$claimId/evidence_${i + 1}.jpg');
    await ref.putFile(
      File(paths[i]),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    urls.add(await ref.getDownloadURL());
  }
  return urls;
}
