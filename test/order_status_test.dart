import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderStatusStyle', () {
    test('"preparando" y "en preparación" se ven igual (En cocina)', () {
      final a = OrderStatusStyle.of('preparando');
      final b = OrderStatusStyle.of('en preparación');
      final c = OrderStatusStyle.of('En Preparacion');

      expect(a.label, 'En cocina');
      expect(b.label, a.label);
      expect(c.label, a.label);
      expect(b.color, a.color);
    });

    test('cada estado conocido tiene su etiqueta', () {
      expect(OrderStatusStyle.of('pendiente').label, 'Pendiente');
      expect(OrderStatusStyle.of('en camino').label, 'En camino');
      expect(OrderStatusStyle.of('entregado').label, 'Entregado');
      expect(OrderStatusStyle.of('cancelado').label, 'Cancelado');
    });

    test('un estado desconocido no rompe y se muestra capitalizado', () {
      expect(OrderStatusStyle.of('reembolsado').label, 'Reembolsado');
      expect(OrderStatusStyle.of('').label, 'Desconocido');
    });
  });
}
