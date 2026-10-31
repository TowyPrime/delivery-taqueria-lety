/// Textos y datos editables del asistente del chat.
///
/// Todos los mensajes son genéricos: cámbialos aquí sin tocar la lógica.
/// Las palabras que activan cada respuesta están en `lib/services/chat_bot.dart`
/// (listas `_returnsWords`, `_claimsWords`, etc.).
class ChatBotConfig {
  ChatBotConfig._();

  // ── Datos del negocio ────────────────────────────────────────────────────

  static const String botName = 'Asistente Lety';

  /// Número de WhatsApp del negocio con lada de país, sin "+" ni espacios.
  /// Ejemplo México: 52 + 10 dígitos → '525512345678'.

  static const String whatsappNumber = '523313982071';

  /// Mensaje que aparece escrito de antemano al abrir WhatsApp.
  static const String whatsappPrefilledText =
      'Hola, necesito ayuda con mi pedido de Taquería Lety.';

  // ── Etiquetas de las respuestas rápidas ──────────────────────────────────

  static const String quickReturns = 'Hacer una devolución';
  static const String quickActiveOrders = 'Estado de mis pedidos';
  static const String quickClaims = 'Seguimiento de reclamaciones';
  static const String quickAdvisor = 'Hablar con un asesor';

  // ── Etiquetas de los botones dentro de las respuestas ────────────────────

  static const String buttonWhatsapp = 'Hablar por WhatsApp';
  static const String buttonLogin = 'Iniciar sesión';

  // ── Mensajes del bot ─────────────────────────────────────────────────────

  static const String welcome =
      '¡Hola! Soy el asistente de Taquería Lety. ¿En qué te puedo ayudar? '
      'Elige una opción o escríbeme tu duda.';

  static const String returnsInfo =
      'Para solicitar la devolución de un pedido entregado:\n'
      '1. Ve a la pestaña "Pedidos" y toca el pedido.\n'
      '2. Pulsa "Solicitar devolución".\n'
      '3. Agrega al menos una foto y explica qué pasó.\n\n'
      'Tu solicitud quedará registrada y podrás ver su estado aquí o en el '
      'detalle del pedido. Si procede y pagaste con tarjeta, el reembolso se '
      'refleja en aproximadamente 24 horas.';

  static const String activeOrdersIntro = 'Estos son tus pedidos en curso:';

  static const String activeOrdersEmpty =
      'Ahora mismo no tienes pedidos activos. Cuando hagas uno, aquí podrás '
      'consultar en qué estado va.';

  static const String activeOrdersFooter =
      'También puedes ver el avance en tiempo real en Notificaciones '
      '(la campana de arriba).';

  static const String loginRequired =
      'Para consultar tus pedidos necesitas iniciar sesión.';

  static const String claimsIntro =
      'Estas son tus reclamaciones más recientes:';

  static const String claimsEmpty =
      'No tienes reclamaciones registradas. Si tuviste un problema con un '
      'pedido entregado, puedes iniciar una desde "Pedidos" → el pedido → '
      '"Solicitar devolución".';

  static const String claimsFooter =
      'Si necesitas más ayuda con alguna, un asesor puede apoyarte por '
      'WhatsApp.';

  static const String errorLoadingClaims =
      'No pude consultar tus reclamaciones en este momento. Inténtalo de '
      'nuevo en unos minutos o habla con un asesor.';

  static const String advisorInfo =
      'Con gusto te comunico con un asesor por WhatsApp. '
      'Toca el botón para abrir la conversación.';

  static const String fallback =
      'No estoy seguro de haber entendido. Puedo ayudarte con estas '
      'opciones (también puedes tocarlas abajo):\n'
      '• Devoluciones\n'
      '• Estado de tus pedidos\n'
      '• Seguimiento de reclamaciones\n'
      '• Hablar con un asesor';

  static const String errorLoadingOrders =
      'No pude consultar tus pedidos en este momento. Inténtalo de nuevo en '
      'unos minutos o habla con un asesor.';

  static const String whatsappOpenError =
      'No pude abrir WhatsApp. Verifica que la aplicación esté instalada.';
}
