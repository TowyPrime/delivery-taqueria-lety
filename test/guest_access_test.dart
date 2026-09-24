import 'package:delivery_app/components/custom_app_bar.dart';
import 'package:delivery_app/components/widgets/login_required_state.dart';
import 'package:delivery_app/screens/login_screen.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_fonts.dart';

Widget _app(Widget body) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: body),
);

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadTestFonts);

  group('AccountMenuButton', () {
    Future<Map<String, int>> pump(
      WidgetTester tester, {
      required bool isGuest,
    }) async {
      _phoneSize(tester);
      final calls = {'profile': 0, 'logout': 0, 'login': 0};
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topRight,
            child: AccountMenuButton(
              isGuest: isGuest,
              onProfile: () => calls['profile'] = calls['profile']! + 1,
              onLogout: () => calls['logout'] = calls['logout']! + 1,
              onLogin: () => calls['login'] = calls['login']! + 1,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AccountMenuButton));
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('invitado: solo "Iniciar sesión", sin perfil ni cerrar sesión', (
      tester,
    ) async {
      final calls = await pump(tester, isGuest: true);

      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Ver perfil'), findsNothing);
      expect(find.text('Cerrar sesión'), findsNothing);

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(calls, {'profile': 0, 'logout': 0, 'login': 1});
    });

    testWidgets('con sesión: perfil y cerrar sesión, sin "Iniciar sesión"', (
      tester,
    ) async {
      final calls = await pump(tester, isGuest: false);

      expect(find.text('Ver perfil'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsNothing);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(calls, {'profile': 0, 'logout': 1, 'login': 0});
    });
  });

  group('LoginRequiredState', () {
    testWidgets('muestra la leyenda y un botón que lleva al inicio de sesión', (
      tester,
    ) async {
      _phoneSize(tester);
      await tester.pumpWidget(
        _app(
          const LoginRequiredState(
            title: 'Inicia sesión para ver tu historial',
            message: 'Aquí verás todos tus pedidos y su estado.',
          ),
        ),
      );

      expect(find.text('Inicia sesión para ver tu historial'), findsOneWidget);
      expect(
        find.text('Aquí verás todos tus pedidos y su estado.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
