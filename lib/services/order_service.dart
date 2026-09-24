import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../providers/cart_provider.dart';

class OrderService {
  // Instancia de Firestore
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Crea un nuevo pedido en la colección 'orders' de Firestore
  static Future<bool> createOrder({
    required BuildContext context,
    required String userId,
    required String userName,
    required CartProvider cart,
    String? paymentIntentId,
  }) async {
    try {
      // Mapeamos los ítems del carrito a un formato de lista que Firestore entienda (Maps)
      final List<Map<String, dynamic>> orderItems = cart.items.values.map((item) {
       if(item.product != null){
        return{
            'type': 'individual', // Nos ayuda a saber qué tipo de item es en la base de datos
      'productId': item.product!.id,
      'name': item.product!.name,
      'price': item.price, // Usamos item.price directo
      'quantity': item.quantity,
      'subtotal': item.price * item.quantity,
        };
       }
       else{
        return{
            'type': 'plato',
            'plateId': item.plato!.id,
            'name': item.plato!.name,
            'price': item.price,
            'quantity': item.quantity,
            'subtotal': item.price * item.quantity,
            'products': item.plato!.products.map((subItem){
              return{
                    'productId': subItem.product.id,
                    'name': subItem.product.name,
                    'quantity': subItem.quantity
              };
            }).toList()
        };
       }
      }).toList();

      // Preparamos el documento completo del pedido
      final Map<String, dynamic> orderData = {
        'userId': userId,
        'userName': userName,
        'items': orderItems,
        'subtotal': cart.subtotal,
        'envio': cart.envio,
        'total': cart.total,
        'status': 'pendiente',                 // Estado inicial del pedido
        'paymentIntentId': paymentIntentId,    // Null si el cobro fue simulado
        'hasClaim': false,
        'claimId': null,
        'createdAt': FieldValue.serverTimestamp(), // Fecha exacta del servidor de Google
      };

      // Guardamos en la colección 'orders'. Firestore generará un ID automático para el documento.
      await _db.collection('orders').add(orderData);

      debugPrint('Pedido guardado exitosamente en Firestore.');
      return true;

    } catch (e) {
      debugPrint('Error al guardar el pedido en Firestore: $e');
      return false;
    }
  }

}