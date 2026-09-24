import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/models/claim_model.dart';
import 'package:delivery_app/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderModel.fromMap', () {
    Map<String, dynamic> base() => {
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'envio': 10,
      'subtotal': 90,
      'total': 100,
      'status': 'entregado',
      'userId': 'u1',
      'userName': 'Prueba',
      'items': [],
    };

    test('lee paymentIntentId, claimId y hasClaim', () {
      final o = OrderModel.fromMap('o1', {
        ...base(),
        'paymentIntentId': 'pi_123',
        'claimId': 'c1',
        'hasClaim': true,
      });

      expect(o.paymentIntentId, 'pi_123');
      expect(o.claimId, 'c1');
      expect(o.hasClaim, isTrue);
    });

    test('pedido nuevo: sin reclamación ni pago real', () {
      final o = OrderModel.fromMap('o1', {
        ...base(),
        'paymentIntentId': null,
        'claimId': null,
        'hasClaim': false,
      });

      expect(o.paymentIntentId, isNull);
      expect(o.claimId, isNull);
      expect(o.hasClaim, isFalse);
    });

    test('pedidos anteriores (sin los campos nuevos) siguen funcionando', () {
      final o = OrderModel.fromMap('o1', base());

      expect(o.paymentIntentId, isNull);
      expect(o.claimId, isNull);
      expect(o.hasClaim, isFalse);
    });

    test('si hay claimId pero falta hasClaim, se deduce true', () {
      final o = OrderModel.fromMap('o1', {...base(), 'claimId': 'c9'});
      expect(o.hasClaim, isTrue);
    });

    test('textos vacíos cuentan como ausentes', () {
      final o = OrderModel.fromMap('o1', {
        ...base(),
        'paymentIntentId': '  ',
        'claimId': '',
      });
      expect(o.paymentIntentId, isNull);
      expect(o.hasClaim, isFalse);
    });

    test('acepta "PaymentIntentId" con mayúscula inicial', () {
      final o = OrderModel.fromMap('o1', {...base(), 'PaymentIntentId': 'pi_9'});
      expect(o.paymentIntentId, 'pi_9');
    });

    test('tolera createdAt pendiente (null) y números enteros', () {
      final o = OrderModel.fromMap('o1', {
        'createdAt': null,
        'total': 100,
        'status': 'pendiente',
        'items': [
          {'name': 'Agua', 'price': 35, 'quantity': 2, 'subtotal': 70},
        ],
      });

      expect(o.total, 100.0);
      expect(o.envio, 0.0);
      expect(o.items.single.price, 35.0);
      expect(o.items.single.quantity, 2);
    });

    test('lee los ingredientes de "products" o de "details"', () {
      final o = OrderModel.fromMap('o1', {
        ...base(),
        'items': [
          {
            'name': 'Plato 1',
            'type': 'plato',
            'quantity': 1,
            'products': [
              {'name': 'Pastor', 'quantity': 3},
            ],
          },
          {
            'name': 'Plato 2',
            'isPlate': true,
            'quantity': 1,
            'details': [
              {'name': 'Bistec', 'quantity': 2},
            ],
          },
        ],
      });

      expect(o.items[0].products.single.name, 'Pastor');
      expect(o.items[1].products.single.quantity, 2);
    });
  });

  group('ClaimStatus / ClaimType', () {
    test('valores guardados en Firestore', () {
      expect(ClaimStatus.abierta.value, 'abierta');
      expect(ClaimStatus.enRevision.value, 'en_revision');
      expect(ClaimStatus.resuelta.value, 'resuelta');
      expect(ClaimStatus.rechazada.value, 'rechazada');
      expect(
        ClaimType.values.map((t) => t.value),
        ['devolucion', 'cancelacion', 'queja', 'otro'],
      );
    });

    test('se leen de vuelta y un valor desconocido no rompe', () {
      expect(ClaimStatus.fromValue('en_revision'), ClaimStatus.enRevision);
      expect(ClaimStatus.fromValue('???'), ClaimStatus.abierta);
      expect(ClaimStatus.fromValue(null), ClaimStatus.abierta);
      expect(ClaimType.fromValue('queja'), ClaimType.queja);
      expect(ClaimType.fromValue('???'), ClaimType.otro);
    });

    test('solo abierta y en revisión cuentan como abiertas', () {
      expect(ClaimStatus.abierta.isOpen, isTrue);
      expect(ClaimStatus.enRevision.isOpen, isTrue);
      expect(ClaimStatus.resuelta.isOpen, isFalse);
      expect(ClaimStatus.rechazada.isOpen, isFalse);
    });
  });

  group('ClaimModel.fromMap', () {
    test('lee todos los campos', () {
      final c = ClaimModel.fromMap('abc123xyz', {
        'orderId': 'o1',
        'userId': 'u1',
        'userName': 'Prueba',
        'type': 'devolucion',
        'reason': 'Llegó dañado',
        'status': 'resuelta',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 2)),
        'orderTotal': 120,
        'orderStatusAtRequest': 'entregado',
        'evidenceUrls': ['u1', 'u2'],
        'contactPhone': '5512345678',
        'resolution': 'Reembolso aprobado',
        'refundAmount': 120,
        'resolvedAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
      });

      expect(c.folio, 'ABC123');
      expect(c.type, ClaimType.devolucion);
      expect(c.status, ClaimStatus.resuelta);
      expect(c.evidenceUrls, ['u1', 'u2']);
      expect(c.orderTotal, 120.0);
      expect(c.refundAmount, 120.0);
      expect(c.resolution, 'Reembolso aprobado');
      expect(c.createdAt, DateTime(2026, 9, 1));
      expect(c.resolvedAt, DateTime(2026, 9, 3));
    });

    test('reclamación recién creada (sin resolución ni fechas del servidor)', () {
      final c = ClaimModel.fromMap('c1', {
        'orderId': 'o1',
        'userId': 'u1',
        'type': 'queja',
        'reason': 'Tardó mucho',
        'status': 'abierta',
        'createdAt': null,
      });

      expect(c.folio, 'C1');
      expect(c.resolution, isNull);
      expect(c.refundAmount, isNull);
      expect(c.evidenceUrls, isEmpty);
      expect(c.status.isOpen, isTrue);
    });
  });
}
