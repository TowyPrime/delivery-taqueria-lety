import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app/models/product_model.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:delivery_app/providers/order_provider.dart';
import 'package:delivery_app/screens/build_plate_screen.dart';

class ListViewMenu extends StatelessWidget {
  final String? orderIdToModify;
  final Map<String, dynamic>? currentOrderData;
  final VoidCallback? onGoToCart;

  const ListViewMenu({
    super.key,
    required this.filteredProducts,
    required this.cartProvider,
    required this.allProducts,
    this.orderIdToModify,
    this.currentOrderData,
    this.onGoToCart,
  });

  final List<ProductModel> filteredProducts;
  final CartProvider cartProvider;
  final List<ProductModel> allProducts;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: AppSpacing.fabClearance),
      itemCount: filteredProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = filteredProducts[index];

        void onAdd() => handleProductSelection(
          context: context,
          product: product,
          cartProvider: cartProvider,
          orderIdToModify: orderIdToModify,
          currentOrderData: currentOrderData,
          onGoToCart: onGoToCart,
        );

        return Card(
          child: InkWell(
            onTap: onAdd,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ProductThumb(url: product.photoUrl, width: 76, height: 76),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          formatMoney(product.price),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Agregar ${product.name}',
                    onPressed: onAdd,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Punto de entrada único para "agregar" un producto, usado por el menú y por
/// la pantalla de inicio. Decide el flujo según la categoría.
void handleProductSelection({
  required BuildContext context,
  required ProductModel product,
  required CartProvider cartProvider,
  String? orderIdToModify,
  Map<String, dynamic>? currentOrderData,
  VoidCallback? onGoToCart,
}) {
  final category = product.category.toLowerCase();

  if (category == 'tacos') {
    // Los tacos siempre van dentro de un plato: pedimos cantidad y armamos el plato.
    _showQuantityDialog(
      context,
      product: product,
      confirmLabel: 'Armar plato',
      note:
          'Los tacos se piden dentro de un plato. Te llevamos a armarlo con esta cantidad.',
      onConfirm: (quantity) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BuildPlateScreen(
              initialProductId: product.id,
              initialProductQuantity: quantity,
            ),
          ),
        );
      },
    );
  } else if (category == 'orden') {
    _showOrderDialog(
      context,
      product,
      cartProvider,
      orderIdToModify,
      currentOrderData,
      onGoToCart,
    );
  } else {
    _showQuantityDialog(
      context,
      product: product,
      confirmLabel: 'Agregar',
      onConfirm: (quantity) async {
        if (orderIdToModify != null && currentOrderData != null) {
          await _executeOrderModification(
            context,
            orderIdToModify,
            currentOrderData,
            product,
            quantity,
          );
        } else {
          cartProvider.addProduct(product, quantity);
          _showAddedSnackBar(context, product.name, onGoToCart);
        }
      },
    );
  }
}

void _showAddedSnackBar(
  BuildContext context,
  String productName,
  VoidCallback? onGoToCart,
) {
  showAppSnackBar(
    context,
    '$productName agregado al carrito',
    kind: SnackKind.success,
    actionLabel: onGoToCart != null ? 'Ver carrito' : null,
    onAction: onGoToCart,
  );
}

void _showQuantityDialog(
  BuildContext context, {
  required ProductModel product,
  required String confirmLabel,
  required void Function(int quantity) onConfirm,
  String? note,
}) {
  int selectedQuantity = 1;

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(product.name, maxLines: 2),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${formatMoney(product.price)} c/u',
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                QuantityStepper(
                  large: true,
                  value: selectedQuantity,
                  onDecrement: selectedQuantity > 1
                      ? () => setDialogState(() => selectedQuantity--)
                      : null,
                  onIncrement: selectedQuantity < 99
                      ? () => setDialogState(() => selectedQuantity++)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  'Total: ${formatMoney(product.price * selectedQuantity)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 16),
                  _InfoNote(text: note),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onConfirm(selectedQuantity);
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showOrderDialog(
  BuildContext context,
  ProductModel product,
  CartProvider cartProvider,
  String? orderIdToModify,
  Map<String, dynamic>? currentOrderData,
  VoidCallback? onGoToCart,
) {
  final int quantity = 1;

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Agregar a tu carrito'),
        content: Text(
          '¿Deseas agregar ${product.name} por ${formatMoney(product.price)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (orderIdToModify != null && currentOrderData != null) {
                await _executeOrderModification(
                  context,
                  orderIdToModify,
                  currentOrderData,
                  product,
                  quantity,
                );
              } else {
                cartProvider.addProduct(product, quantity);
                _showAddedSnackBar(context, product.name, onGoToCart);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      );
    },
  );
}

class _InfoNote extends StatelessWidget {
  final String text;

  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _executeOrderModification(
  BuildContext context,
  String orderId,
  Map<String, dynamic> currentOrderData,
  ProductModel product,
  int quantity,
) async {
  try {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    //Extrer lista de productos original
    List<dynamic> currentItems = List.from(currentOrderData['items'] ?? []);
    double currentTotal = (currentOrderData['total'] ?? 0.0).toDouble();

    //Si el producto ya existe
    int existingIndex = currentItems.indexWhere(
      (item) => item['id'] == product.id,
    );

    if (existingIndex != -1) {
      int oldQty = currentItems[existingIndex]['quantity'] ?? 1;
      currentItems[existingIndex]['quantity'] = oldQty + quantity;
    } else {
      currentItems.add({
        'id': product.id,
        'name': product.name,
        'price': product.price,
        'quantity': quantity,
      });
    }

    double extraCost = product.price * quantity;
    double newTotal = currentTotal + extraCost;

    await orderProvider.updateOrderContent(orderId, currentItems, newTotal);

    if (context.mounted) {
      showAppSnackBar(
        context,
        '${product.name} agregado directamente a la orden activa',
        kind: SnackKind.success,
      );
      Navigator.pop(context);
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        'Error al modificar el pedido: $e',
        kind: SnackKind.error,
      );
    }
  }
}
