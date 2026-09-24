import 'package:delivery_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/components/widgets/home/home_scaffold.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onGoToMenu;
  final VoidCallback onGotoCart;
  const HomeScreen({
    super.key,
    required this.onGoToMenu,
    required this.onGotoCart,
    });

  @override
  Widget build(BuildContext context) {
    // Escuchamos el estado de autenticación para saber si es invitado o no
    final authProvider = Provider.of<AppAuthProvider>(context);

    return HomeScaffold(authProvider: authProvider, onGoToMenu: onGoToMenu, onGotoCart: onGotoCart);
  }
}

