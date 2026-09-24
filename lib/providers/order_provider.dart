import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/models/order_model.dart';
import 'package:delivery_app/services/notification_service.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, String> _lastViewedStatuses = {};

  final Map<String, String> _lastNotifiedStatuses = {};

  void markStatusAsRead(String orderId, String currentStatus) {
    _lastViewedStatuses[orderId] = currentStatus;
    notifyListeners();
  }

  bool hasUnreadStatusUpdate(List<OrderModel> activeOrders) {
    if (activeOrders.isEmpty) return false;

    for (var order in activeOrders) {
      final orderId = order.id;
      final currentStatus = order.status;

      //Si el pedido es nuevo
      if (!_lastViewedStatuses.containsKey(orderId) ||
          _lastViewedStatuses[orderId] != currentStatus) {
        return true;
      }
    }
    return false;
  }

  //Estado de carga
  List<OrderModel> _userOrders = [];
  bool _isLoading = false;

  List<OrderModel> get userOrders => _userOrders;
  bool get isLoading => _isLoading;

  //Escuchar pedidos en tiempo real
  Stream<OrderModel> streamOrder(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((snapshot) => OrderModel.fromFirestore(snapshot));
  }

  //Traer pedidos de usuario
  Future<void> fetchUserOrders(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1) // Los más recientes primero
          .get();
      _userOrders = querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
        .where('status', whereIn: ['pendiente', 'preparando', 'en camino'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();

          for (var order in orders) {
            final orderId = order.id;
            final currentStatus = order.status;

            if (!_lastNotifiedStatuses.containsKey(orderId) ||
                _lastNotifiedStatuses[orderId] != currentStatus) {
              NotificationService.showNotification(
                id: orderId.hashCode,
                title: 'Actualización de pedido',
                body: 'El estado de tu pedido ha cambiado a: $currentStatus',
              );
              _lastNotifiedStatuses[orderId] = currentStatus;
            }
          }

          return orders;
        });
  }

  //modificar el contenido del pedido
  Future<void> updateOrderContent(
    String orderId,
    List<dynamic> updateItems,
    double newTotal,
  ) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'items': updateItems,
        'total': newTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Error al actualizar el pedido: $e');
      rethrow;
    }
  }

  //Cancelar  un pedido
  Future<void> cancelOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelado',
      });
    } catch (e) {
      debugPrint('Error al cancelar pedido: $e');
      rethrow;
    }
  }
}
