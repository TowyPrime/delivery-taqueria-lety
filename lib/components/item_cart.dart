import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

class ItemCart extends StatelessWidget {
  final String cartItemId;
  final CartItem item;

  const ItemCart({super.key, required this.cartItemId, required this.item});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Determinamos nombre y precio
    final String displayName =
        item.product?.name ?? item.plato?.name ?? 'Plato';
    final double unitPrice = item.price;
    final bool isPlate = item.plato != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPlate)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.dinner_dining_rounded,
                      color: AppColors.accent,
                      size: 30,
                    ),
                  )
                else
                  ProductThumb(
                    url: item.product?.photoUrl ?? '',
                    width: 56,
                    height: 56,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatMoney(unitPrice)} c/u',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botón eliminar por completo (Usa la llave del mapa)
                IconButton(
                  tooltip: 'Quitar del carrito',
                  visualDensity: VisualDensity.compact,
                  color: AppColors.danger,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => cartProvider.removeProduct(cartItemId),
                ),
              ],
            ),

            // Si es un plato, desglosamos los tacos que incluye abajo
            if (isPlate && item.plato!.products.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.plato!.products.map((ingredient) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ingredient.quantity}× ${ingredient.product.name}',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                QuantityStepper(
                  value: item.quantity,
                  // Botón menos cantidad
                  onDecrement: () =>
                      cartProvider.decrementProductQuantity(cartItemId),
                  // Botón más cantidad
                  onIncrement: () {
                    if (item.product != null) {
                      // Si es un producto regular, usamos tu función existente
                      cartProvider.addProduct(item.product!, 1);
                    } else if (item.plato != null) {
                      // Si es un plato, incrementamos su cantidad directamente en la línea
                      cartProvider.incrementProductQuantity(cartItemId);
                    }
                  },
                ),
                const Spacer(),
                Text(
                  formatMoney(unitPrice * item.quantity),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
