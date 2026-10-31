import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/models/order_model.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, String> _lastViewedStatuses = {};

  void markStatusAsRead(String orderId, String currentStatus) {
    _lastViewedStatuses[orderId] = currentStatus;
    notifyListeners();
  }

  bool hasUnreadStatusUpdate(List<OrderModel> activeOrders) {
    if (activeOrders.isEmpty) return false;

    for (var order in activeOrders) {
      final orderId = order.id;
      final currentStatus = order.status;

      // Si el pedido es nuevo
      if (!_lastViewedStatuses.containsKey(orderId) ||
          _lastViewedStatuses[orderId] != currentStatus) {
        return true;
      }
    }
    return false;
  }

  // Estado de carga
  final _isLoading = false;

  bool get isLoading => _isLoading;

  // Escuchar pedidos en tiempo real
  Stream<OrderModel> streamOrder(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((snapshot) => OrderModel.fromFirestore(snapshot));
  }

  /// Consulta única de TODOS los pedidos en curso del usuario (sin notificar
  /// ni recordar estados, a diferencia de [streamActiveOrders]).
  Future<List<OrderModel>> fetchActiveOrders(String userId) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where(
          'status',
          whereIn: ['pendiente', 'preparando', 'en preparación', 'en camino'],
        )
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  }

  Stream<List<OrderModel>> streamActiveOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where(
          'status',
          whereIn: ['pendiente', 'en preparación', 'preparando', 'en camino'],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Cancelar un pedido
  Future<void> cancelOrder(String orderId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('cancelOrder');
      await callable.call({'orderId': orderId});
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'Error de Firebase Functions al cancelar pedido: ${e.message}',
      );
      throw Exception(e.message ?? "No se pudo cancelar el pedido");
    }
  }
}
