import 'package:delivery_app/config/chat_bot_config.dart';
import 'package:delivery_app/models/chat_message.dart';
import 'package:delivery_app/models/claim_model.dart';
import 'package:delivery_app/models/order_model.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum BotIntent { returns, activeOrders, claims, advisor, greeting, unknown }

/// Bot sencillo basado en reglas (palabras clave); no usa IA ni servidor.
///
/// No depende de Firebase: el acceso a los pedidos y el estado de sesión se
/// inyectan, así que se puede probar sin conexión.
class ChatBot {
  ChatBot({
    required this.isLoggedIn,
    required this.loadActiveOrders,
    required this.loadClaims,
  });

  /// ¿Hay una sesión real (no invitado)?
  final bool Function() isLoggedIn;

  /// Trae los pedidos en curso del usuario actual.
  final Future<List<OrderModel>> Function() loadActiveOrders;

  /// Trae las reclamaciones más recientes del usuario actual.
  final Future<List<ClaimModel>> Function() loadClaims;

  // Palabras clave (ya sin acentos ni mayúsculas). Se revisan en este orden:
  // asesor → reclamaciones → devoluciones → pedidos → saludo.
  static const _advisorWords = [
    'asesor',
    'whatsapp',
    'whats',
    'humano',
    'agente',
    'contactar',
    'hablar con',
  ];
  static const _claimsWords = ['reclam', 'queja', 'inconform', 'disputa'];
  static const _returnsWords = ['devol', 'reembols', 'cancel'];
  static const _ordersWords = [
    'estado',
    'pedido',
    'donde',
    'tarda',
    'activo',
    'rastre',
    'seguimiento',
    'entrega',
  ];
  static const _greetingWords = ['hola', 'buenas', 'buen dia', 'buenos dias'];

  /// Quita acentos y mayúsculas para comparar con las palabras clave.
  static String _normalize(String input) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    var out = input.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  static bool _hasAny(String text, List<String> words) =>
      words.any(text.contains);

  static BotIntent detectIntent(String input) {
    final text = _normalize(input);
    if (_hasAny(text, _advisorWords)) return BotIntent.advisor;
    if (_hasAny(text, _claimsWords)) return BotIntent.claims;
    if (_hasAny(text, _returnsWords)) return BotIntent.returns;
    if (_hasAny(text, _ordersWords)) return BotIntent.activeOrders;
    if (_hasAny(text, _greetingWords)) return BotIntent.greeting;
    return BotIntent.unknown;
  }

  Future<List<ChatMessage>> respondToText(String text) =>
      respondTo(detectIntent(text));

  Future<List<ChatMessage>> respondTo(BotIntent intent) async {
    switch (intent) {
      case BotIntent.returns:
        return [_bot(ChatBotConfig.returnsInfo)];
      case BotIntent.claims:
        return [await _claimsReply()];
      case BotIntent.advisor:
        return [
          _bot(ChatBotConfig.advisorInfo, actions: [BotAction.openWhatsApp]),
        ];
      case BotIntent.activeOrders:
        return [await _activeOrdersReply()];
      case BotIntent.greeting:
        return [_bot(ChatBotConfig.welcome)];
      case BotIntent.unknown:
        return [_bot(ChatBotConfig.fallback)];
    }
  }

  Future<ChatMessage> _activeOrdersReply() async {
    if (!isLoggedIn()) {
      return _bot(
        ChatBotConfig.loginRequired,
        actions: [BotAction.goToLogin],
      );
    }

    try {
      final orders = await loadActiveOrders();
      if (orders.isEmpty) return _bot(ChatBotConfig.activeOrdersEmpty);

      final lines = orders.map((o) {
        final id = o.id.substring(0, o.id.length < 6 ? o.id.length : 6);
        final status = OrderStatusStyle.of(o.status).label;
        return '• Pedido #${id.toUpperCase()} · $status · '
            '\$${o.total.toStringAsFixed(2)} MXN';
      });

      return _bot(
        '${ChatBotConfig.activeOrdersIntro}\n\n${lines.join('\n')}\n\n'
        '${ChatBotConfig.activeOrdersFooter}',
      );
    } catch (e) {
      debugPrint('ChatBot: error al consultar pedidos activos: $e');
      return _bot(
        ChatBotConfig.errorLoadingOrders,
        actions: [BotAction.openWhatsApp],
      );
    }
  }

  Future<ChatMessage> _claimsReply() async {
    if (!isLoggedIn()) {
      return _bot(
        ChatBotConfig.loginRequired,
        actions: [BotAction.goToLogin],
      );
    }

    try {
      final claims = await loadClaims();
      if (claims.isEmpty) return _bot(ChatBotConfig.claimsEmpty);

      final date = DateFormat('dd/MM/yyyy');
      final lines = claims.map((c) {
        final order = c.orderId.substring(
          0,
          c.orderId.length < 6 ? c.orderId.length : 6,
        );
        final base =
            '• #${c.folio} · Pedido #${order.toUpperCase()} · '
            '${c.status.label} · ${date.format(c.createdAt)}';
        return c.resolution == null
            ? base
            : '$base\n   Respuesta: ${c.resolution}';
      });

      return _bot(
        '${ChatBotConfig.claimsIntro}\n\n${lines.join('\n')}\n\n'
        '${ChatBotConfig.claimsFooter}',
        actions: [BotAction.openWhatsApp],
      );
    } catch (e) {
      debugPrint('ChatBot: error al consultar reclamaciones: $e');
      return _bot(
        ChatBotConfig.errorLoadingClaims,
        actions: [BotAction.openWhatsApp],
      );
    }
  }

  ChatMessage _bot(String text, {List<BotAction> actions = const []}) =>
      ChatMessage(text: text, fromBot: true, actions: actions);
}
