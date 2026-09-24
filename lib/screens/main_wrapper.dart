import 'package:delivery_app/components/custom_app_bar.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:delivery_app/screens/admin_screen.dart';
import 'package:delivery_app/screens/cart_screen.dart';
import 'package:delivery_app/screens/chat_screen.dart';
import 'package:delivery_app/screens/menu_screen.dart';
import 'package:delivery_app/screens/notification_screen.dart';
import 'package:delivery_app/screens/profile_screen.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:delivery_app/screens/order_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  //Metodo para cambiar de pestaña
  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    //Lista de pantallas en orden
    final List<Widget> screens = [
      HomeScreen(
        onGoToMenu: () => _onTabTapped(1),
        onGotoCart: () => _onTabTapped(2),
      ),
      MenuScreen(onGoToCart: () => _onTabTapped(2)),
      CartScreen(onGoToMenu: () => _onTabTapped(1)),
      const OrderScreen(),
      const AdminScreen(),
      const NotificationScreen(),
      ProfileScreen(
        onbackToHome: () => _onTabTapped(0),
        onNavigateToAdmin: () => _onTabTapped(4),
      ),
    ];
    return Scaffold(
      appBar: CustomAppBar(
        title: getTitleForIndex(_currentIndex),
        centerTitle: true,
        showBackButton: _currentIndex != 0,
        onBackPressed: () => _onTabTapped(0),
        onNotificationTap: () => _onTabTapped(5),
        onProfileTap: () => _onTabTapped(6),
      ),
      body: IndexedStack(index: _currentIndex, children: screens),

      // Botón del asistente. Se oculta en el Carrito para no tapar "Pasar al cobro".
      floatingActionButton: _currentIndex == 2
          ? null
          : FloatingActionButton(
              tooltip: 'Chatea con nosotros',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
              child: const Icon(Icons.chat_bubble_rounded),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex < 5 ? _currentIndex : 0,
        onDestinationSelected: _onTabTapped,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Menú',
          ),
          NavigationDestination(
            icon: _CartIcon(selected: false),
            selectedIcon: _CartIcon(selected: true),
            label: 'Carrito',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Pedidos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Mis datos',
          ),
        ],
      ),
    );
  }
}

/// Icono del carrito con la cantidad de artículos como insignia.
class _CartIcon extends StatelessWidget {
  final bool selected;

  const _CartIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartProvider, int>((c) => c.totalItemsCount);
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(
        selected ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined,
      ),
    );
  }
}

String getTitleForIndex(int index) {
  switch (index) {
    case 0:
      return 'Taquería Lety';
    case 1:
      return 'Menú';
    case 2:
      return 'Carrito';
    case 3:
      return 'Pedidos';
    case 4:
      return 'Mis datos';
    case 5:
      return 'Notificaciones';
    case 6:
      return 'Perfil';
    default:
      return '';
  }
}
