import 'package:delivery_app/config/chat_bot_config.dart';
import 'package:delivery_app/models/chat_message.dart';
import 'package:delivery_app/models/claim_model.dart';
import 'package:delivery_app/models/order_model.dart';
import 'package:delivery_app/screens/chat_screen.dart';
import 'package:delivery_app/screens/login_screen.dart';
import 'package:delivery_app/services/chat_bot.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_fonts.dart';

OrderModel _order(String id, String status, double total) => OrderModel(
  id: id,
  createdAt: DateTime(2026, 1, 1),
  envio: 10,
  subtotal: total - 10,
  total: total,
  status: status,
  userId: 'u1',
  userName: 'Prueba',
  items: const [],
);

ClaimModel _claim(
  String id,
  ClaimStatus status, {
  String orderId = 'ord123456',
  String? resolution,
  DateTime? createdAt,
}) => ClaimModel(
  id: id,
  orderId: orderId,
  userId: 'u1',
  type: ClaimType.devolucion,
  reason: 'Llegó incompleto',
  status: status,
  createdAt: createdAt ?? DateTime(2026, 9, 12),
  resolution: resolution,
);

ChatBot _bot({
  bool loggedIn = true,
  List<OrderModel> orders = const [],
  List<ClaimModel> claims = const [],
  Object? error,
  Object? claimsError,
  void Function()? onLoad,
  void Function()? onLoadClaims,
}) => ChatBot(
  isLoggedIn: () => loggedIn,
  loadActiveOrders: () async {
    onLoad?.call();
    if (error != null) throw error;
    return orders;
  },
  loadClaims: () async {
    onLoadClaims?.call();
    if (claimsError != null) throw claimsError;
    return claims;
  },
);

void main() {
  setUpAll(loadTestFonts);

  group('ChatBot.detectIntent', () {
    test('devoluciones', () {
      expect(
        ChatBot.detectIntent('¿Cómo hago una devolución de mi pedido?'),
        BotIntent.returns,
      );
      expect(ChatBot.detectIntent('quiero cancelar'), BotIntent.returns);
      expect(ChatBot.detectIntent('Quiero un REEMBOLSO'), BotIntent.returns);
    });

    test('estado de pedidos', () {
      expect(ChatBot.detectIntent('¿dónde está mi pedido?'), BotIntent.activeOrders);
      expect(ChatBot.detectIntent('cuánto tarda'), BotIntent.activeOrders);
    });

    test('reclamaciones tiene prioridad sobre "seguimiento"/"pedido"', () {
      expect(
        ChatBot.detectIntent('seguimiento de mi reclamación'),
        BotIntent.claims,
      );
      expect(ChatBot.detectIntent('tengo una queja de mi pedido'), BotIntent.claims);
    });

    test('asesor / WhatsApp tiene prioridad sobre todo', () {
      expect(ChatBot.detectIntent('quiero hablar con un asesor'), BotIntent.advisor);
      expect(ChatBot.detectIntent('pásame tu whatsapp'), BotIntent.advisor);
      expect(
        ChatBot.detectIntent('una devolución, con un asesor por favor'),
        BotIntent.advisor,
      );
    });

    test('saludo y desconocido', () {
      expect(ChatBot.detectIntent('HOLA'), BotIntent.greeting);
      expect(ChatBot.detectIntent('Hola, quiero una devolución'), BotIntent.returns);
      expect(ChatBot.detectIntent('asdf qwerty'), BotIntent.unknown);
    });
  });

  group('ChatBot.respondTo', () {
    test('devolución: explica los pasos, sin botones', () async {
      final r = await _bot().respondTo(BotIntent.returns);
      expect(r.single.text, ChatBotConfig.returnsInfo);
      expect(r.single.actions, isEmpty);
    });

    test('asesor ofrece WhatsApp', () async {
      final r = await _bot().respondTo(BotIntent.advisor);
      expect(r.single.actions, [BotAction.openWhatsApp]);
    });

    test('reclamaciones sin sesión: pide login y no consulta', () async {
      var loaded = false;
      final r = await _bot(
        loggedIn: false,
        onLoadClaims: () => loaded = true,
      ).respondTo(BotIntent.claims);

      expect(r.single.text, ChatBotConfig.loginRequired);
      expect(r.single.actions, [BotAction.goToLogin]);
      expect(loaded, isFalse);
    });

    test('reclamaciones: sin ninguna', () async {
      final r = await _bot().respondTo(BotIntent.claims);
      expect(r.single.text, ChatBotConfig.claimsEmpty);
    });

    test('reclamaciones: lista folio, pedido, estado, fecha y respuesta', () async {
      final r = await _bot(
        claims: [
          _claim('abc123xyz', ClaimStatus.enRevision),
          _claim(
            'def456uvw',
            ClaimStatus.resuelta,
            orderId: 'zzz999qqq',
            resolution: 'Reembolso aprobado',
            createdAt: DateTime(2026, 8, 1),
          ),
        ],
      ).respondTo(BotIntent.claims);

      final text = r.single.text;
      expect(text, contains(ChatBotConfig.claimsIntro));
      expect(text, contains('#ABC123 · Pedido #ORD123 · En revisión · 12/09/2026'));
      expect(text, contains('#DEF456 · Pedido #ZZZ999 · Resuelta · 01/08/2026'));
      expect(text, contains('Respuesta: Reembolso aprobado'));
      expect(text, contains(ChatBotConfig.claimsFooter));
      expect(r.single.actions, [BotAction.openWhatsApp]);
    });

    test('reclamaciones: si falla la consulta responde con error y asesor', () async {
      final r = await _bot(
        claimsError: Exception('sin red'),
      ).respondTo(BotIntent.claims);
      expect(r.single.text, ChatBotConfig.errorLoadingClaims);
      expect(r.single.actions, [BotAction.openWhatsApp]);
    });

    test('pedidos activos sin sesión: pide login y no consulta', () async {
      var loaded = false;
      final r = await _bot(
        loggedIn: false,
        onLoad: () => loaded = true,
      ).respondTo(BotIntent.activeOrders);

      expect(r.single.text, ChatBotConfig.loginRequired);
      expect(r.single.actions, [BotAction.goToLogin]);
      expect(loaded, isFalse);
    });

    test('pedidos activos: lista id, estado y total', () async {
      final r = await _bot(
        orders: [
          _order('abc123xyz', 'preparando', 120),
          _order('zzz999qqq', 'en camino', 75.5),
        ],
      ).respondTo(BotIntent.activeOrders);

      final text = r.single.text;
      expect(text, contains(ChatBotConfig.activeOrdersIntro));
      expect(text, contains('#ABC123 · En cocina · \$120.00 MXN'));
      expect(text, contains('#ZZZ999 · En camino · \$75.50 MXN'));
      expect(text, contains(ChatBotConfig.activeOrdersFooter));
    });

    test('pedidos activos: sin pedidos', () async {
      final r = await _bot().respondTo(BotIntent.activeOrders);
      expect(r.single.text, ChatBotConfig.activeOrdersEmpty);
    });

    test('pedidos activos: si falla la consulta responde con error y asesor', () async {
      final r = await _bot(error: Exception('sin red')).respondTo(BotIntent.activeOrders);
      expect(r.single.text, ChatBotConfig.errorLoadingOrders);
      expect(r.single.actions, [BotAction.openWhatsApp]);
    });

    test('desconocido: respuesta de ayuda', () async {
      final r = await _bot().respondTo(BotIntent.unknown);
      expect(r.single.text, ChatBotConfig.fallback);
    });
  });

  group('ChatScreen', () {
    void phoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    Future<void> pump(
      WidgetTester tester, {
      ChatBot? bot,
      Future<bool> Function()? openWhatsApp,
    }) async {
      phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChatScreen(
            bot: bot ?? _bot(),
            openWhatsApp: openWhatsApp ?? () async => true,
            replyDelay: Duration.zero,
          ),
        ),
      );
    }

    Future<void> tapChip(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la bienvenida y las 4 respuestas rápidas', (tester) async {
      await pump(tester);

      expect(find.text(ChatBotConfig.welcome), findsOneWidget);
      for (final label in [
        ChatBotConfig.quickReturns,
        ChatBotConfig.quickActiveOrders,
        ChatBotConfig.quickClaims,
        ChatBotConfig.quickAdvisor,
      ]) {
        expect(find.text(label, skipOffstage: false), findsOneWidget);
      }
    });

    testWidgets('respuesta rápida: aparece la pregunta y la respuesta del bot', (
      tester,
    ) async {
      await pump(tester);

      await tapChip(tester, ChatBotConfig.quickReturns);

      // La pregunta queda como burbuja del usuario (además del chip).
      expect(find.text(ChatBotConfig.quickReturns), findsNWidgets(2));
      expect(find.text(ChatBotConfig.returnsInfo), findsOneWidget);
    });

    testWidgets('texto libre: detecta la intención y ofrece WhatsApp', (tester) async {
      var opened = 0;
      await pump(
        tester,
        openWhatsApp: () async {
          opened++;
          return true;
        },
      );

      await tester.enterText(find.byType(TextField), 'quiero hablar con un asesor');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text(ChatBotConfig.advisorInfo), findsOneWidget);

      await tester.tap(find.text(ChatBotConfig.buttonWhatsapp));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('si WhatsApp no abre, muestra un aviso', (tester) async {
      await pump(tester, openWhatsApp: () async => false);

      await tapChip(tester, ChatBotConfig.quickAdvisor);
      await tester.tap(find.text(ChatBotConfig.buttonWhatsapp));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(ChatBotConfig.whatsappOpenError), findsOneWidget);
    });

    testWidgets('texto que no entiende: responde con la ayuda', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'asdf qwerty');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(find.text(ChatBotConfig.fallback), findsOneWidget);
    });

    testWidgets('invitado pidiendo sus pedidos: botón que lleva al login', (
      tester,
    ) async {
      await pump(tester, bot: _bot(loggedIn: false));

      await tapChip(tester, ChatBotConfig.quickActiveOrders);
      expect(find.text(ChatBotConfig.loginRequired), findsOneWidget);

      await tester.tap(find.text(ChatBotConfig.buttonLogin));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('con sesión: lista los pedidos activos', (tester) async {
      await pump(
        tester,
        bot: _bot(orders: [_order('abc123xyz', 'pendiente', 99)]),
      );

      await tapChip(tester, ChatBotConfig.quickActiveOrders);

      expect(find.textContaining('#ABC123 · Pendiente'), findsOneWidget);
    });
  });
}
