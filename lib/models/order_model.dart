import 'package:cloud_firestore/cloud_firestore.dart';

double _asDouble(Object? v) => (v as num?)?.toDouble() ?? 0.0;
int _asInt(Object? v) => (v as num?)?.toInt() ?? 0;

class OrderModel {
  final String id;
  final DateTime createdAt;
  final double envio;
  final double subtotal;
  final double total;
  final String status;
  final String userId;
  final String userName;
  final List<OrderItem> items;

  /// Id del PaymentIntent de Stripe con el que se pagó (necesario para
  /// reembolsos). Es null si el pedido se creó sin un cobro real.
  final String? paymentIntentId;

  /// Id de la reclamación asociada, si el cliente ya inició una.
  final String? claimId;

  /// Verdadero si el pedido ya tiene una reclamación (evita duplicarla).
  final bool hasClaim;

  const OrderModel({
    required this.id,
    required this.createdAt,
    required this.envio,
    required this.subtotal,
    required this.total,
    required this.status,
    required this.userId,
    required this.userName,
    required this.items,
    this.paymentIntentId,
    this.claimId,
    this.hasClaim = false,
  });

  //Mapear desde Firebase
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    return OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// Igual que [fromFirestore] pero desde un mapa (útil para pruebas).
  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    final String? claimId = _nonEmpty(data['claimId']);
    final String? paymentIntentId = _nonEmpty(
      data['paymentIntentId'] ?? data['PaymentIntentId'],
    );

    return OrderModel(
      id: id,
      // Mientras el servidor no confirma el serverTimestamp, createdAt es null.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      envio: _asDouble(data['envio']),
      subtotal: _asDouble(data['subtotal']),
      total: _asDouble(data['total']),
      status: data['status'] ?? 'pendiente',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      paymentIntentId: paymentIntentId,
      claimId: claimId,
      // Si el campo hasClaim no existe (pedidos anteriores), lo deducimos.
      hasClaim: data['hasClaim'] as bool? ?? claimId != null,
    );
  }

  static String? _nonEmpty(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}

class OrderItem {
  final String name;
  final String plateId;
  final double price;
  final int quantity;
  final double subtotal;
  final String type;
  final List<OrderProduct> products;

  const OrderItem({
    required this.name,
    required this.plateId,
    required this.price,
    required this.quantity,
    required this.subtotal,
    required this.type,
    required this.products,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      name: map['name'] ?? '',
      plateId: map['plateId'] ?? '',
      price: _asDouble(map['price']),
      quantity: _asInt(map['quantity']),
      subtotal: _asDouble(map['subtotal']),
      type: map['type'] ?? '',
      // Los platos usan "products" (carrito) o "details" (pedido modificado).
      products: (map['products'] as List<dynamic>? ??
              map['details'] as List<dynamic>? ??
              [])
          .map((prod) => OrderProduct.fromMap(prod as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrderProduct {
  final String name;
  final String productId;
  final int quantity;

  const OrderProduct({
    required this.name,
    required this.productId,
    required this.quantity,
  });

  factory OrderProduct.fromMap(Map<String, dynamic> map) {
    return OrderProduct(
      name: map['name'] ?? '',
      productId: map['productId'] ?? '',
      quantity: _asInt(map['quantity']),
    );
  }
}
