import 'package:delivery_app/models/product_model.dart';
import 'package:flutter/material.dart';

Future<void> showPackageDetailSheet(
  BuildContext context, {
  required ProductModel product,
  required void Function(int quantity) onAdd,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      int quantity = 1;
      return StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadiusGeometry.circular(16),
                    child: product.photoUrl.isNotEmpty
                        ? Image.network(
                            product.photoUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  product.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (product.contents.isNotEmpty) ...[
                  const Text(
                    "Incluye",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...product.contents.map(
                    (item) => Padding(
                      padding: const EdgeInsetsGeometry.symmetric(
                        vertical: 4.0,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (product.description.isNotEmpty) ...[
                  Text(
                    product.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline),
                      onPressed: quantity > 1
                          ? () {
                              setSheetState(() {
                                quantity--;
                              });
                            }
                          : null,
                    ),
                    Padding(
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 16),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setSheetState(() {
                          quantity++;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onAdd(quantity);
                    },
                    child: Text(
                      'Añadir al carrito • \$${(product.price * quantity).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
