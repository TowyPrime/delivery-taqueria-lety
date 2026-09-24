import 'package:delivery_app/models/plate_model.dart';
import 'package:delivery_app/models/product_model.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

ProductModel _product(String id, double price) => ProductModel(
  id: id,
  name: 'Producto $id',
  price: price,
  category: 'tacos',
  description: '',
);

PlateModel _plate(ProductModel p) => PlateModel(
  id: 'plate',
  name: 'Plato 1',
  price: p.price * 2,
  products: [PlateItem(product: p, quantity: 2)],
);

void main() {
  group('CartProvider', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test('agregar el mismo producto suma cantidades', () {
      final p = _product('1', 10);
      cart.addProduct(p, 2);
      cart.addProduct(p, 3);

      expect(cart.items, hasLength(1));
      expect(cart.items['1']!.quantity, 5);
      expect(cart.totalItemsCount, 5);
    });

    test('total = subtotal + envío', () {
      cart.addProduct(_product('1', 10), 2);
      cart.addProduct(_product('2', 5), 1);

      expect(cart.subtotal, 25);
      expect(cart.total, 25 + cart.envio);
    });

    test('incrementar un plato suma exactamente 1 (regresión)', () {
      cart.addPlate(_plate(_product('1', 10)));
      final key = cart.items.keys.single;

      cart.incrementProductQuantity(key);

      expect(cart.items[key]!.quantity, 2);
    });

    test('decrementar desde 1 elimina la línea y el plato', () {
      cart.addPlate(_plate(_product('1', 10)));
      final key = cart.items.keys.single;
      expect(cart.numberPlates, 2);

      cart.decrementProductQuantity(key);

      expect(cart.items, isEmpty);
      expect(cart.numberPlates, 1);
    });

    test('el carrito no pasa de 100 unidades por línea', () {
      cart.addProduct(_product('1', 10), 100);
      cart.incrementProductQuantity('1');

      expect(cart.items['1']!.quantity, 100);
    });

    test('clearCart vacía productos y platos', () {
      cart.addProduct(_product('1', 10), 1);
      cart.addPlate(_plate(_product('2', 5)));

      cart.clearCart();

      expect(cart.items, isEmpty);
      expect(cart.numberPlates, 1);
    });
  });
}
