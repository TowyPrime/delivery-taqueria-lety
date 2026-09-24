/// Botones que puede mostrar una respuesta del bot debajo del texto.
enum BotAction { openWhatsApp, goToLogin }

class ChatMessage {
  final String text;
  final bool fromBot;
  final List<BotAction> actions;

  const ChatMessage({
    required this.text,
    required this.fromBot,
    this.actions = const [],
  });
}
