import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/components/widgets/menu/list_view_menu.dart';
import 'package:delivery_app/models/product_model.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:delivery_app/screens/login_screen.dart';
import 'package:delivery_app/screens/register_screen.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/test_fonts.dart';

final _products = <ProductModel>[
  ProductModel(
    id: '1',
    name: 'Tacos al pastor',
    price: 85,
    category: 'tacos',
    description: 'Orden de 5 tacos.',
  ),
  ProductModel(
    id: '2',
    name: 'Orden de gringas',
    price: 120,
    category: 'orden',
    description: 'Con queso.',
  ),
  ProductModel(
    id: '3',
    name: 'Agua de horchata',
    price: 35,
    category: 'bebida',
    description: 'Vaso grande.',
  ),
];

Widget _app(Widget home, {CartProvider? cart}) {
  return ChangeNotifierProvider<CartProvider>.value(
    value: cart ?? CartProvider(),
    child: MaterialApp(theme: AppTheme.light, home: home),
  );
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadTestFonts);

  group('Login', () {
    testWidgets('"Crea una aquí" abre el registro sin diálogo de confirmación', (
      tester,
    ) async {
      _phoneSize(tester);
      await tester.pumpWidget(_app(const LoginScreen()));

      await tester.tap(find.text('Crea una aquí'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  group('Menú', () {
    Future<CartProvider> pumpMenu(WidgetTester tester) async {
      _phoneSize(tester);
      final cart = CartProvider();
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ListViewMenu(
              filteredProducts: _products,
              cartProvider: cart,
              allProducts: _products,
              onGoToCart: () {},
            ),
          ),
          cart: cart,
        ),
      );
      return cart;
    }

    testWidgets('muestra nombre y precio de cada producto', (tester) async {
      await pumpMenu(tester);

      expect(find.text('Tacos al pastor'), findsOneWidget);
      expect(find.text(formatMoney(120)), findsOneWidget);
      expect(find.text('Agua de horchata'), findsOneWidget);
    });

    testWidgets('agregar una bebida: stepper, total en vivo y al carrito', (
      tester,
    ) async {
      final cart = await pumpMenu(tester);

      // Tercer "+" = Agua de horchata.
      await tester.tap(find.byIcon(Icons.add_rounded).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Total: ${formatMoney(35)}'), findsOneWidget);

      // "+" del diálogo (el último del árbol) sube a 2 unidades.
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Total: ${formatMoney(70)}'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(cart.items['3']!.quantity, 2);
      expect(find.text('Agua de horchata agregado al carrito'), findsOneWidget);
      expect(find.text('Ver carrito'), findsOneWidget);
    });

    testWidgets('el diálogo no permite bajar de 1 unidad', (tester) async {
      await pumpMenu(tester);

      await tester.tap(find.byIcon(Icons.add_rounded).at(2));
      await tester.pumpAndSettle();

      final minus = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_rounded),
      );
      expect(minus.onPressed, isNull);
    });
  });

  group('EmptyState', () {
    testWidgets('el botón de acción llama al callback', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Tu carrito está vacío',
              actionLabel: 'Ver el menú',
              onAction: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ver el menú'));
      expect(pressed, isTrue);
    });
  });
}
