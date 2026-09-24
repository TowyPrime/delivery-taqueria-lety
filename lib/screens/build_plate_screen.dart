import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/custom_app_bar.dart';
import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:delivery_app/models/product_model.dart';
import 'package:delivery_app/models/plate_model.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:delivery_app/providers/order_provider.dart'; // <--- Import del OrderProvider
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BuildPlateScreen extends StatefulWidget {
  final String initialProductId;
  final int initialProductQuantity;
  final String? orderIdToModify; 
  final Map<String, dynamic>? currentOrderData; 

  const BuildPlateScreen({
    super.key,
    required this.initialProductId,
    required this.initialProductQuantity,
    this.orderIdToModify,
    this.currentOrderData,
  });

  @override
  State<BuildPlateScreen> createState() => _BuildPlateScreenState();
}

class _BuildPlateScreenState extends State<BuildPlateScreen> {
  // Mapa para controlar productos en el plato
  final Map<String, int> _selectedProducts = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialProductId.isNotEmpty) {
      _selectedProducts[widget.initialProductId] =
          widget.initialProductQuantity;
    }
  }

  // Contador de productos
  int get _totalProductsInPlate {
    return _selectedProducts.values.fold(0, (plus, qty) => plus + qty);
  }

  // Cálculo del precio del plato
  double _currentPlatePrice(List<ProductModel> availableProducts) {
    double total = 0.0;
    _selectedProducts.forEach((productId, qty) {
      final product = availableProducts.firstWhere(
        (p) => p.id == productId,
        orElse: () => ProductModel(
          id: '',
          name: '',
          price: 0.0,
          category: '',
          description: "",
        ),
      );
      total += product.price * qty;
    });
    return total;
  }

  void _addProductToPlate(String productId) {
    setState(() {
      _selectedProducts[productId] = (_selectedProducts[productId] ?? 0) + 1;
    });
  }

  void _removeProductToPlate(String productId) {
    if (!_selectedProducts.containsKey(productId)) return;
    setState(() {
      if (_selectedProducts[productId] == 1) {
        _selectedProducts.remove(productId);
      } else {
        _selectedProducts[productId] = _selectedProducts[productId]! - 1;
      }
    });
  }

  Future<void> _addPlateToCart(List<ProductModel> availableProducts) async {
    if (_totalProductsInPlate == 0) return;
    

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final List<PlateItem> plateProducts = [];

    _selectedProducts.forEach((productId, qty) {
      final product = availableProducts.firstWhere((p) => p.id == productId);
      plateProducts.add(PlateItem(product: product, quantity: qty));
    });

    final double platePrice = _currentPlatePrice(availableProducts);

    
    if (widget.orderIdToModify != null && widget.currentOrderData != null) {
      try {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);

        List<dynamic> currentItems = List.from(widget.currentOrderData!['items'] ?? []);
        double currentTotal = (widget.currentOrderData!['total'] ?? 0.0).toDouble();

        // Convertimos el plato a la estructura de Map para Firestore
        currentItems.add({
          'id': 'plate_${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Plato ${cartProvider.numberPlates}',
          'price': platePrice,
          'quantity': 1,
          'isPlate': true,
          'details': plateProducts.map((item) => {
            'name': item.product.name,
            'quantity': item.quantity,
          }).toList(),
        });

        double newTotal = currentTotal + platePrice;

        await orderProvider.updateOrderContent(
          widget.orderIdToModify!,
          currentItems,
          newTotal,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plato agregado al pedido activo'),
              backgroundColor: AppColors.success,
            ),
          );

        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al agregar plato al pedido: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } else {
      // Flujo tradicional: Guardar en el carrito local
      final newPlate = PlateModel(
        id: 'Plate_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Plato ${cartProvider.numberPlates}',
        price: platePrice,
        products: plateProducts,
      );

      cartProvider.addPlate(newPlate);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plato agregado al carrito'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool modifyingOrder = widget.orderIdToModify != null;

    return Scaffold(
      appBar: CustomAppBar(
        title: modifyingOrder ? 'Arma tu plato para el pedido' : 'Arma tu plato',
        centerTitle: true,
        showBackButton: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('isPackage', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar los ingredientes',
              message: 'Revisa tu conexión e inténtalo de nuevo.',
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: 'No hay ingredientes disponibles',
            );
          }

          final List<ProductModel> tacoProducts = snapshot.data!.docs
              .map((doc) {
                return ProductModel.fromFirestore(doc.data(), doc.id);
              })
              .where((product) => product.category.toLowerCase() == 'tacos')
              .toList();

          if (tacoProducts.isEmpty) {
            return const EmptyState(
              icon: Icons.dinner_dining_rounded,
              title: 'No hay productos en la sección de tacos',
            );
          }

          final double platePrice = _currentPlatePrice(tacoProducts);
          final String ctaLabel = modifyingOrder
              ? 'Agregar plato al pedido'
              : 'Agregar plato al carrito';

          return Column(
            children: [
              // Resumen del plato
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.dinner_dining_rounded,
                      color: AppColors.warning,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tu plato',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _totalProductsInPlate == 1
                                ? '1 producto'
                                : '$_totalProductsInPlate productos',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(platePrice),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de productos en el plato
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: tacoProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final producto = tacoProducts[index];
                    final cantidadActual = _selectedProducts[producto.id] ?? 0;
                    final bool selected = cantidadActual > 0;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ProductThumb(
                              url: producto.photoUrl,
                              width: 60,
                              height: 60,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formatMoney(producto.price)} c/u',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (selected)
                              QuantityStepper(
                                value: cantidadActual,
                                onDecrement: () =>
                                    _removeProductToPlate(producto.id),
                                onIncrement: () =>
                                    _addProductToPlate(producto.id),
                              )
                            else
                              IconButton.filled(
                                tooltip: 'Agregar ${producto.name}',
                                onPressed: () =>
                                    _addProductToPlate(producto.id),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.add_rounded),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Botón para finalizar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: FilledButton(
                    onPressed: _totalProductsInPlate == 0
                        ? null
                        : () => _addPlateToCart(tacoProducts),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: Text(
                      _totalProductsInPlate == 0
                          ? 'Agrega al menos un producto'
                          : '$ctaLabel · ${formatMoney(platePrice)}',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
