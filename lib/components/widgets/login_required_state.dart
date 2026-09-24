import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/screens/login_screen.dart';
import 'package:flutter/material.dart';

/// Pantalla vacía para secciones que requieren cuenta (Pedidos, Mis datos):
/// explica por qué no hay contenido y ofrece un botón directo al inicio de sesión.
class LoginRequiredState extends StatelessWidget {
  final String title;
  final String message;

  const LoginRequiredState({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_outline_rounded,
      title: title,
      message: message,
      actionLabel: 'Iniciar sesión',
      onAction: () => goToLogin(context),
    );
  }
}
