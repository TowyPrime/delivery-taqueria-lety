import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/models/product_model.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/widgets/menu/list_view_menu.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback? onGoToCart;

  const MenuScreen({super.key, this.onGoToCart});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final List<String> _categories = [
    'Todos',
    'Tacos',
    'Orden',
    'Bebida',
    'Postre',
  ];

  static const Map<String, IconData> _categoryIcons = {
    'Todos': Icons.apps_rounded,
    'Tacos': Icons.restaurant_rounded,
    'Orden': Icons.dinner_dining_rounded,
    'Bebida': Icons.local_drink_rounded,
    'Postre': Icons.icecream_rounded,
  };

  final _searchController = TextEditingController();
  String _selectedCategory = 'Todos';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Configuración dinámica de la Query
    final Query query = FirebaseFirestore.instance
        .collection('products')
        .where('isPackage', isEqualTo: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar tacos, bebidas, postres…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // Chips de Filtro por Categoría
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _CategoryChip(
                  label: category,
                  icon: _categoryIcons[category] ?? Icons.restaurant_rounded,
                  selected: _selectedCategory == category,
                  onTap: () => setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Lista de productos filtrados en tiempo real
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'No pudimos cargar el menú',
                    message: 'Revisa tu conexión e inténtalo de nuevo.',
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'Aún no hay productos',
                    message: 'Estamos preparando el menú. ¡Vuelve pronto!',
                  );
                }

                final allProducts = snapshot.data!.docs.map((doc) {
                  return ProductModel.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                }).toList();

                // Aplicar filtros locales (Categorías y Búsqueda)
                final filteredProducts = allProducts.where((product) {
                  final matchesCategory =
                      _selectedCategory == 'Todos' ||
                      product.category.toLowerCase() ==
                          _selectedCategory.toLowerCase();

                  final matchesSearch =
                      product.name.toLowerCase().contains(_searchQuery) ||
                      product.description.toLowerCase().contains(_searchQuery);

                  return matchesCategory && matchesSearch;
                }).toList();

                if (filteredProducts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No encontramos lo que buscas',
                    message: 'Prueba con otro nombre o cambia de categoría.',
                  );
                }

                return ListViewMenu(
                  filteredProducts: filteredProducts,
                  cartProvider: cartProvider,
                  allProducts: allProducts,
                  onGoToCart: widget.onGoToCart,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? Colors.white : AppColors.ink;
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderStrong,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
