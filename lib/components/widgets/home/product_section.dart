import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/components/widgets/menu/list_view_menu.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/models/product_model.dart';

/// Sección de la pantalla de inicio: título + carrusel horizontal de productos.
class ProductSection extends StatelessWidget {
  final String title;
  final Query query;
  final VoidCallback onGotoCart;
  final VoidCallback? onSeeAll;
  final bool showImage;
  final bool isFeatured;

  const ProductSection({
    super.key,
    required this.title,
    required this.query,
    required this.onGotoCart,
    this.onSeeAll,
    this.showImage = true,
    this.isFeatured = false,
  });

  static const double _cardWidth = 186;
  static const double _carouselHeight = 268;

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          actionLabel: onSeeAll != null ? 'Ver todo' : null,
          onAction: onSeeAll,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _carouselHeight,
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint('Error cargando "$title": ${snapshot.error}');
                return const _SectionMessage(
                  icon: Icons.wifi_off_rounded,
                  text: 'No pudimos cargar esta sección.',
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const _SectionMessage(
                  icon: Icons.restaurant_menu_rounded,
                  text: 'Por ahora no hay productos disponibles.',
                );
              }

              final products = snapshot.data!.docs.map((doc) {
                return ProductModel.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                );
              }).toList();

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return SizedBox(
                    width: _cardWidth,
                    child: _ProductCard(
                      product: product,
                      isPromo: !isFeatured,
                      showImage: showImage,
                      onAdd: () => handleProductSelection(
                        context: context,
                        product: product,
                        cartProvider: cartProvider,
                        onGoToCart: onGotoCart,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isPromo;
  final bool showImage;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product,
    required this.isPromo,
    required this.showImage,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ProductThumb(
                  url: showImage ? product.photoUrl : '',
                  width: double.infinity,
                  height: 118,
                  radius: 0,
                  fallbackIcon: isPromo
                      ? Icons.local_offer_rounded
                      : Icons.restaurant_rounded,
                ),
                if (isPromo)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PROMO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatMoney(product.price),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
