import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/models/order_model.dart';
import 'package:delivery_app/providers/auth_provider.dart';
import 'package:delivery_app/providers/order_provider.dart';
import 'package:delivery_app/screens/login_screen.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum MenuOption { viewProfile, logout, login }

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  const CustomAppBar({
    super.key,
    this.title = '',
    this.centerTitle = false,
    this.showBackButton = false,
    this.onBackPressed,
    this.onNotificationTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final String? currentUserId = authProvider.currentUserId;

    return AppBar(
      centerTitle: centerTitle,
      leadingWidth: 64,
      leading: showBackButton
          ? IconButton(
              tooltip: 'Regresar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (onBackPressed != null) {
                  onBackPressed!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            )
          : const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: BrandLogo(size: 40),
            ),
      title: Text(title.isEmpty ? 'Taquería Lety' : title),
      actions: [
        if (currentUserId != null)
          // Envolvemos en un Consumer para reaccionar cuando marquemos las órdenes como leídas
          Consumer<OrderProvider>(
            builder: (context, orderProvider, child) {
              return StreamBuilder<List<OrderModel>>(
                stream: orderProvider.streamActiveOrders(currentUserId),
                builder: (context, snapshot) {
                  // Si no hay internet o no hay pedidos en curso
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return _NotificationButton(
                      hasUnread: false,
                      onPressed: () {
                        if (onNotificationTap != null) onNotificationTap!();
                      },
                    );
                  }

                  final activeOrders = snapshot.data!;

                  // Usamos el método de tu OrderProvider para saber si hay estados sin leer
                  final bool showRedBadge = orderProvider.hasUnreadStatusUpdate(
                    activeOrders,
                  );

                  return _NotificationButton(
                    hasUnread: showRedBadge,
                    // Al presionar, marcamos como leídos y cambiamos de pantalla
                    onPressed: () {
                      for (var order in activeOrders) {
                        orderProvider.markStatusAsRead(order.id, order.status);
                      }
                      if (onNotificationTap != null) onNotificationTap!();
                    },
                  );
                },
              );
            },
          )
        else
          // Si por algo el usuario no está logueado
          _NotificationButton(
            hasUnread: false,
            onPressed: () {
              if (onNotificationTap != null) onNotificationTap!();
            },
          ),
        AccountMenuButton(
          isGuest: authProvider.needsLogin,
          onProfile: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (onProfileTap != null) onProfileTap!();
            });
          },
          onLogout: () {
            AppAuthProvider auth = Provider.of<AppAuthProvider>(
              context,
              listen: false,
            );
            auth.signOut();
            showAppSnackBar(
              context,
              'Cerraste sesión con éxito',
              kind: SnackKind.success,
            );
            _navigateToLogin(context);
          },
          onLogin: () => goToLogin(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _navigateToLogin(BuildContext context) {
    // Usamos pushReplacement para que al cerrar sesión no puedan usar el botón "atrás" del cel y regresar al Home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

/// Campana de notificaciones con punto rojo cuando hay novedades sin leer.
class _NotificationButton extends StatelessWidget {
  final bool hasUnread;
  final VoidCallback onPressed;

  const _NotificationButton({required this.hasUnread, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: hasUnread,
        smallSize: 10,
        backgroundColor: AppColors.primary,
        child: Icon(
          hasUnread
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: hasUnread ? AppColors.primary : AppColors.ink,
        ),
      ),
    );
  }
}

/// Menú de la cuenta en la barra superior.
///
/// * Con sesión: "Ver perfil" y "Cerrar sesión".
/// * Invitado (sin sesión o anónimo): solo "Iniciar sesión".
class AccountMenuButton extends StatelessWidget {
  final bool isGuest;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final VoidCallback onLogin;

  const AccountMenuButton({
    super.key,
    required this.isGuest,
    required this.onProfile,
    required this.onLogout,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MenuOption>(
      tooltip: 'Cuenta',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (MenuOption option) {
        switch (option) {
          case MenuOption.viewProfile:
            onProfile();
          case MenuOption.logout:
            onLogout();
          case MenuOption.login:
            onLogin();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<MenuOption>>[
        if (isGuest)
          const PopupMenuItem<MenuOption>(
            value: MenuOption.login,
            child: Row(
              children: [
                Icon(Icons.login_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Text(
                  'Iniciar sesión',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        else ...const [
          PopupMenuItem<MenuOption>(
            value: MenuOption.viewProfile,
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 20),
                SizedBox(width: 10),
                Text('Ver perfil'),
              ],
            ),
          ),
          PopupMenuItem<MenuOption>(
            value: MenuOption.logout,
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                SizedBox(width: 10),
                Text(
                  'Cerrar sesión',
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
