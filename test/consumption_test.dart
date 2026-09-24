import 'package:delivery_app/components/consumption_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('consumptionByProduct', () {
    test('suma productos individuales entre pedidos', () {
      final result = consumptionByProduct([
        {
          'items': [
            {'type': 'individual', 'name': 'Horchata', 'quantity': 2},
          ],
        },
        {
          'items': [
            {'type': 'individual', 'name': 'Horchata', 'quantity': 1},
            {'type': 'individual', 'name': 'Flan', 'quantity': 1},
          ],
        },
      ]);

      expect(result, {'Horchata': 3, 'Flan': 1});
    });

    test('desglosa un plato del carrito (type: plato) por su cantidad', () {
      final result = consumptionByProduct([
        {
          'items': [
            {
              'type': 'plato',
              'name': 'Plato 1',
              'quantity': 2,
              'products': [
                {'name': 'Pastor', 'quantity': 3},
                {'name': 'Bistec', 'quantity': 1},
              ],
            },
          ],
        },
      ]);

      expect(result, {'Pastor': 6, 'Bistec': 2});
    });

    test('desglosa un plato agregado a un pedido (isPlate + details)', () {
      final result = consumptionByProduct([
        {
          'items': [
            {
              'isPlate': true,
              'name': 'Plato 2',
              'quantity': 1,
              'details': [
                {'name': 'Pastor', 'quantity': 4},
              ],
            },
          ],
        },
      ]);

      expect(result, {'Pastor': 4});
      expect(result.containsKey('Plato 2'), isFalse);
    });

    test('tolera datos incompletos o cantidades decimales', () {
      final result = consumptionByProduct([
        {},
        {
          'items': [
            {'name': 'Agua', 'quantity': 2.0},
            {'quantity': 1},
          ],
        },
      ]);

      expect(result, {'Agua': 2, 'Desconocido': 1});
    });
  });
}
