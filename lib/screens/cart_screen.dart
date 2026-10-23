import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/services/order_service.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/services/payment_service.dart';
import 'package:delivery_app/components/item_cart.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/services/delivery_zone_service.dart';

class CartScreen extends StatelessWidget {
  final VoidCallback? onGoToMenu;

  const CartScreen({super.key, this.onGoToMenu});

  //Verificar si el usuario tiene una dirección dentro de la zona de reparto
  Future<bool> _checkDeliveryZone(BuildContext context) async {
    final uid = Provider.of<AppAuthProvider>(context, listen: false).user?.uid;
    if (uid == null) return false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? problema;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final dir = snap.data()?['direccion'] as Map<String, dynamic>?;
      final lat = (dir?['lat'] as num).toDouble();
      final lng = (dir?['lng'] as num).toDouble();

      if (dir == null || (dir['calle'] ?? '').toString().trim().isEmpty) {
        problema =
            'Aún no tienes una dirección de envío. Agrégala en "Mis datos" para poder pedir.';
      } else if (lat == null || lng == null) {
        problema =
            'No pudimos ubicar tu dirección. Revísala en "Mis datos" (calle, colonia y C.P.) y guárdala de nuevo.';
      } else {
        final zona = await DeliveryZoneService().checkCoordinates(lat, lng);
        if (!zona.inside) {
          problema =
              'Tu dirección queda a ${zona.distanceKm.toStringAsFixed(1)} km de la taquería, fuera de nuestra zona de reparto.';
        }
      }
    } catch (_) {
      problema =
          'No pudimos verificar tu zona de reparto. Revisa tu conexión e intenta de nuevo.';
    }

    if (context.mounted) Navigator.pop(context);
    if (problema == null) return true;

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No podemos hacer el envío'),
          content: Text(problema!),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  Future<void> _processStripePayment(
    BuildContext context,
    CartProvider cartProvider,
  ) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    //Mostrar indicador de carga en lo que se conecta al servidor
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    //Llamar al servicio de cobro
    final PaymentResult payment = await PaymentService.makePayment(
      context: context,
      totalAmount: cartProvider.total,
    );

    //Quitar el indicador de carga
    if (context.mounted) Navigator.pop(context);

    if (payment.success) {
      if (!context.mounted) return;

      // El cobro ya se hizo: no vaciamos el carrito hasta tener el pedido
      // guardado, y si falla dejamos reintentar sin volver a cobrar.
      final bool orderSaved = await _saveOrderWithRetry(
        context,
        authProvider,
        cartProvider,
        payment.paymentIntentId,
      );

      if (orderSaved) {
        if (context.mounted) {
          showAppSnackBar(
            context,
            '¡Pedido confirmado! Tu pedido está siendo procesado',
            kind: SnackKind.success,
          );
        }
        //limpiar carrito
        cartProvider.clearCart();
        //resetear cuenta de platos
        cartProvider.clearListPlates();
      }
    } else {
      // Si falla o se cancela
      if (context.mounted) {
        showAppSnackBar(
          context,
          'No pudo realizarse el cobro, intenta de nuevo...',
          kind: SnackKind.error,
        );
      }
    }
  }

  /// Guarda el pedido en Firestore. Si falla, avisa y permite reintentar
  /// (el carrito se conserva). Devuelve true solo si el pedido quedó guardado.
  Future<bool> _saveOrderWithRetry(
    BuildContext context,
    AppAuthProvider authProvider,
    CartProvider cartProvider,
    String? paymentIntentId,
  ) async {
    while (true) {
      if (!context.mounted) return false;

      //Mostrar la carga mientras se guarda en base de datos la orden
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      //Intentar guardar pedido en base de datos
      final bool saved = await OrderService.createOrder(
        context: context,
        userId: authProvider.user?.uid ?? 'anon_uid',
        userName:
            authProvider.user?.displayName ??
            authProvider.user?.email ??
            'cliente',
        cart: cartProvider,
        paymentIntentId: paymentIntentId,
      );

      //Quitar indicador de carga
      if (context.mounted) Navigator.pop(context);
      if (saved) return true;
      if (!context.mounted) return false;

      final bool? retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No pudimos registrar tu pedido'),
          content: const Text(
            'Tu pago se realizó correctamente, pero hubo un problema al '
            'guardar el pedido. Tu carrito sigue intacto: reintenta para no '
            'perder tu compra.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );

      if (retry != true) {
        if (context.mounted) {
          showAppSnackBar(
            context,
            'Tu pedido no quedó registrado. Conserva tu comprobante de pago y contacta a la taquería.',
            kind: SnackKind.error,
            duration: const Duration(seconds: 8),
          );
        }
        return false;
      }
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
                label: 'Subtotal',
                value: '${formatMoney(cartProvider.subtotal)} MXN',
              ),
              AmountRow(
                label: 'Costo de envío',
                value: '${formatMoney(cartProvider.envio)} MXN',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              AmountRow(
                label: 'Total',
                value: '${formatMoney(cartProvider.total)} MXN',
                isTotal: true,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  if (authProvider.isGuest) {
                    _showAuthRequiredDialog(context);
                  } else {
                    // Flujo de cobro
                    _processStripePayment(context, cartProvider);
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
