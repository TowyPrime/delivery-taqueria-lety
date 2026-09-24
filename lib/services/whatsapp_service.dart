import 'package:delivery_app/config/chat_bot_config.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre una conversación de WhatsApp con el negocio (app instalada o WhatsApp
/// Web como respaldo). Devuelve false si no se pudo abrir.
Future<bool> openBusinessWhatsApp({
  String number = ChatBotConfig.whatsappNumber,
  String message = ChatBotConfig.whatsappPrefilledText,
}) async {
  final uri = Uri.https('wa.me', '/$number', {'text': message});
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('No se pudo abrir WhatsApp: $e');
    return false;
  }
}
