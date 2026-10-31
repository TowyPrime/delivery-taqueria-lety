import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/services/payment_service.dart';
import 'package:delivery_app/components/item_cart.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class CartScreen extends StatelessWidget {
  final VoidCallback? onGoToMenu;

  const CartScreen({super.key, this.onGoToMenu});

  Future<void> _checkout(
    BuildContext context,
    CartProvider cartProvider,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await PaymentService.checkout(cartProvider);

    if (!context.mounted) return;
    Navigator.pop(context); // quita el indicador de carga

    switch (result.status) {
      case CheckoutStatus.paid:
        showAppSnackBar(
          context,
          '¡Pedido confirmado! Tu pedido está siendo procesado',
          kind: SnackKind.success,
        );
        cartProvider.clearCart();
        cartProvider.clearListPlates();
      case CheckoutStatus.cancelled:
        showAppSnackBar(context, 'Pago cancelado', kind: SnackKind.info);
      case CheckoutStatus.failed:
        showAppSnackBar(
          context,
          result.message ?? 'No pudo realizarse el cobro',
          kind: SnackKind.error,
          duration: const Duration(seconds: 6),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos activamente los cambios en el carrito y en la autenticación
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AppAuthProvider>(context);

    // Convertimos las entradas del mapa del carrito en una lista para el ListView
    final cartKeys = cartProvider.items.keys.toList();
    final cartItems = cartProvider.items.values.toList();

    if (cartItems.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Tu carrito está vacío',
        message: '¡Agrega algún producto del menú para empezar tu pedido!',
        actionLabel: onGoToMenu != null ? 'Ver el menú' : null,
        onAction: onGoToMenu,
      );
    }

    final int articles = cartProvider.totalItemsCount;

    return Column(
      children: [
        //Lista de productos
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: cartItems.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    articles == 1 ? '1 artículo' : '$articles artículos',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                );
              }
              final key = cartKeys[index - 1];
              final item = cartItems[index - 1];
              // Le pasamos el item real a tu componente personalizado
              return ItemCart(cartItemId: key, item: item);
            },
          ),
        ),

        // Desglose financiero + botón de cobro
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLarge),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmountRow(
                label: 'Total',
                value: '${formatMoney(cartProvider.subtotal)} MXN',
                isTotal: true,
              ),
              Text(
                "El costo de envío se agregará al pagar",
                style: TextStyle(color: const Color(0xFF57534E), fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  if (authProvider.isGuest) {
                    _showAuthRequiredDialog(context);
                  } else {
                    _checkout(context, cartProvider);
                  }
                },
                icon: const Icon(Icons.lock_outline_rounded, size: 20),
                label: const Text('Pasar al cobro'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAuthRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¡Ya casi están tus tacos!'),
          content: const Text(
            'Para poder enviar tu pedido a Taquería Lety y calcular tu ruta de entrega, necesitas registrarte o iniciar sesión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
              child: const Text('Seguir viendo'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                goToLogin(context);
              },
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Iniciar sesión'),
            ),
          ],
        );
      },
    );
  }
}
