import 'package:delivery_app/models/plate_model.dart';
import 'package:delivery_app/models/product_model.dart';
import 'package:flutter/material.dart';

class CartItem {
  final ProductModel? product;
  final PlateModel? plato;
  final double price;
  int quantity;

  CartItem({this.product, this.quantity = 1, this.price = 0.0, this.plato});
}

class CartProvider with ChangeNotifier {
  // Mapa interno: Key = ID del producto o ID generado para el plato
  final Map<String, CartItem> _items = {};
  final List<PlateModel> _listPlates = [];

  // Getter para obtener los items del carrito
  Map<String, CartItem> get items => _items;

  int get totalItemsCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  // Cálculos
  double get subtotal {
    return items.values.fold(
      0.0,
      (total, item) => total + (item.price * item.quantity),
    );
  }

  double get envio => 10.0;
  double get total => subtotal + envio;
  int get numberPlates => _listPlates.length + 1;

  // Acciones del carrito
  void addProduct(ProductModel product, int quantity) {
    if (_items.containsKey(product.id)) {
      // Se suma la cantidad real seleccionada por el usuario
      _items[product.id]!.quantity += quantity;
    } else {
      _items[product.id] = CartItem(
        product: product,
        price: product.price,
        quantity: quantity,
      );
    }
    notifyListeners();
  }

  void addPlate(PlateModel newPlate) {
  
    _listPlates.add(newPlate);

    final String uniqueId = 'plate_${DateTime.now().millisecondsSinceEpoch}';

    _items[uniqueId] = CartItem(
      product: null,
      plato: newPlate,
      price: newPlate.price,
      quantity: 1,
    );
    notifyListeners();
  }

  void removeProduct(String keyId) {
    if (_items.containsKey(keyId)) {
      // Si era un plato, lo eliminamos también de _listPlates
      if (_items[keyId]!.plato != null) {
        _listPlates.remove(_items[keyId]!.plato);
      }
      _items.remove(keyId);
      notifyListeners();
    }
  }

  void decrementProductQuantity(String keyId) {
    if (!_items.containsKey(keyId)) return;

    if (_items[keyId]!.quantity > 1) {
      _items[keyId]!.quantity--;
    } else {
      removeProduct(keyId); // Usa removeProduct para limpiar también si era plato
      return;
    }
    notifyListeners();
  }

  void incrementProductQuantity(String keyId) {
    if (!_items.containsKey(keyId)) return;

    if (_items[keyId]!.quantity < 100) {
      _items[keyId]!.quantity++;
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _listPlates.clear(); // ✅ CORREGIDO: Limpia los platos creados al vaciar el carrito
    notifyListeners();
  }

  void clearListPlates() {
    _listPlates.clear();
  }
}