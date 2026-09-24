import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/models/claim_model.dart';
import 'package:delivery_app/services/claim_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _reason = 'El pedido llegó incompleto y frío.';

void main() {
  late FakeFirebaseFirestore db;
  late List<Map<String, Object?>> uploads;
  late ClaimService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    uploads = [];
    service = ClaimService(
      firestore: db,
      uploader: ({required userId, required claimId, required paths}) async {
        uploads.add({'userId': userId, 'claimId': claimId, 'paths': paths});
        return [for (var i = 0; i < paths.length; i++) 'https://x/$claimId/$i'];
      },
    );

    await db.collection('orders').doc('o1').set({
      'userId': 'u1',
      'status': 'entregado',
      'total': 120,
      'hasClaim': false,
      'claimId': null,
    });
  });

  Future<String> create({
    String orderId = 'o1',
    String userId = 'u1',
    String reason = _reason,
    List<String> paths = const ['/tmp/a.jpg'],
    ClaimType type = ClaimType.devolucion,
    String? phone = '5512345678',
  }) => service.createClaim(
    orderId: orderId,
    userId: userId,
    userName: 'Prueba',
    type: type,
    reason: reason,
    evidencePaths: paths,
    orderTotal: 120,
    orderStatus: 'entregado',
    contactPhone: phone,
  );

  group('createClaim', () {
    test('guarda la reclamación y marca el pedido', () async {
      final id = await create();

      final claim = (await db.collection('claims').doc(id).get()).data()!;
      expect(claim['orderId'], 'o1');
      expect(claim['userId'], 'u1');
      expect(claim['userName'], 'Prueba');
      expect(claim['type'], 'devolucion');
      expect(claim['reason'], _reason);
      expect(claim['status'], 'abierta');
      expect(claim['orderTotal'], 120);
      expect(claim['orderStatusAtRequest'], 'entregado');
      expect(claim['contactPhone'], '5512345678');
      expect(claim['evidenceUrls'], ['https://x/$id/0']);
      expect(claim['createdAt'], isA<Timestamp>());
      expect(claim['updatedAt'], isA<Timestamp>());
      // Los campos del negocio no los escribe el cliente.
      expect(claim.containsKey('resolution'), isFalse);
      expect(claim.containsKey('refundAmount'), isFalse);
      expect(claim.containsKey('resolvedAt'), isFalse);

      final order = (await db.collection('orders').doc('o1').get()).data()!;
      expect(order['hasClaim'], isTrue);
      expect(order['claimId'], id);
      // El pedido conserva su estado (la reclamación tiene el suyo).
      expect(order['status'], 'entregado');
    });

    test('sube las fotos con el usuario y el id de la reclamación', () async {
      final id = await create(paths: ['/a.jpg', '/b.jpg']);

      expect(uploads.single, {
        'userId': 'u1',
        'claimId': id,
        'paths': ['/a.jpg', '/b.jpg'],
      });
    });

    test('recorta el motivo y omite el teléfono vacío', () async {
      final id = await create(reason: '   $_reason   ', phone: '  ');

      final claim = (await db.collection('claims').doc(id).get()).data()!;
      expect(claim['reason'], _reason);
      expect(claim.containsKey('contactPhone'), isFalse);
    });

    test('motivo demasiado corto: error y no toca nada', () async {
      await expectLater(
        create(reason: 'muy corto'),
        throwsA(isA<ClaimException>()),
      );

      expect(uploads, isEmpty);
      expect((await db.collection('claims').get()).docs, isEmpty);
    });

    test('exige al menos una foto', () async {
      await expectLater(
        create(paths: const []),
        throwsA(
          isA<ClaimException>().having(
            (e) => e.message,
            'message',
            contains('al menos una foto'),
          ),
        ),
      );
      expect(uploads, isEmpty);
    });

    test('máximo 3 fotos', () async {
      await expectLater(
        create(paths: ['/1.jpg', '/2.jpg', '/3.jpg', '/4.jpg']),
        throwsA(isA<ClaimException>()),
      );
    });

    test('no permite una segunda reclamación del mismo pedido', () async {
      await create();
      uploads.clear();

      await expectLater(
        create(),
        throwsA(
          isA<ClaimException>().having(
            (e) => e.message,
            'message',
            contains('ya tiene una reclamación'),
          ),
        ),
      );
      // Falla antes de subir fotos y no crea otra reclamación.
      expect(uploads, isEmpty);
      expect((await db.collection('claims').get()).docs, hasLength(1));
    });

    test('un pedido de otro usuario no se puede reclamar', () async {
      await expectLater(
        create(userId: 'otro'),
        throwsA(isA<ClaimException>()),
      );
      expect(uploads, isEmpty);
    });

    test('pedido inexistente', () async {
      await expectLater(
        create(orderId: 'no-existe'),
        throwsA(isA<ClaimException>()),
      );
    });

    test('si falla la subida de fotos no se guarda nada', () async {
      final failing = ClaimService(
        firestore: db,
        uploader: ({required userId, required claimId, required paths}) async {
          throw Exception('sin red');
        },
      );

      await expectLater(
        failing.createClaim(
          orderId: 'o1',
          userId: 'u1',
          userName: 'Prueba',
          type: ClaimType.queja,
          reason: _reason,
          evidencePaths: const ['/a.jpg'],
          orderTotal: 120,
          orderStatus: 'entregado',
        ),
        throwsA(isA<ClaimException>()),
      );

      expect((await db.collection('claims').get()).docs, isEmpty);
      final order = (await db.collection('orders').doc('o1').get()).data()!;
      expect(order['hasClaim'], isFalse);
    });
  });

  group('consultas', () {
    Future<void> seed(String id, String userId, DateTime at) =>
        db.collection('claims').doc(id).set({
          'orderId': 'o-$id',
          'userId': userId,
          'type': 'devolucion',
          'reason': 'x' * 12,
          'status': 'abierta',
          'createdAt': Timestamp.fromDate(at),
        });

    test('fetchUserClaims: solo las del usuario, de la más nueva a la más vieja', () async {
      await seed('vieja', 'u1', DateTime(2026, 1, 1));
      await seed('nueva', 'u1', DateTime(2026, 3, 1));
      await seed('media', 'u1', DateTime(2026, 2, 1));
      await seed('ajena', 'u2', DateTime(2026, 4, 1));

      final claims = await service.fetchUserClaims('u1');

      expect(claims.map((c) => c.id), ['nueva', 'media', 'vieja']);
    });

    test('fetchUserClaims respeta el límite', () async {
      await seed('a', 'u1', DateTime(2026, 1, 1));
      await seed('b', 'u1', DateTime(2026, 2, 1));
      await seed('c', 'u1', DateTime(2026, 3, 1));

      final claims = await service.fetchUserClaims('u1', limit: 2);

      expect(claims.map((c) => c.id), ['c', 'b']);
    });

    test('streamClaim emite el modelo y null si no existe', () async {
      await seed('c1', 'u1', DateTime(2026, 1, 1));

      final claim = await service.streamClaim('c1').first;
      expect(claim!.id, 'c1');
      expect(claim.status, ClaimStatus.abierta);

      expect(await service.streamClaim('nope').first, isNull);
    });
  });
}
