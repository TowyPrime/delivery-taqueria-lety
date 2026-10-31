import 'package:cloud_functions/cloud_functions.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

enum CheckoutStatus { paid, cancelled, failed }

class CheckoutResult {
  final CheckoutStatus status;
  final String? orderId;
  final String? message;

  const CheckoutResult(this.status, {this.orderId, this.message});
}

class PaymentService {
  PaymentService._();

  /// Solo mandamos ids y cantidades: los precios los calcula el servidor.
  static List<Map<String, dynamic>> _buildItems(CartProvider cart) {
    return cart.items.values.map((item) {
      if (item.product != null) {
        return {
          'type': 'individual',
          'productId': item.product!.id,
          'quantity': item.quantity,
        };
      }
      return {
        'type': 'plato',
        'quantity': item.quantity,
        'products': item.plato!.products
            .map((p) => {'productId': p.product.id, 'quantity': p.quantity})
            .toList(),
      };
    }).toList();
  }

  static Future<CheckoutResult> checkout(CartProvider cart) async {
    try {
      // 1. El servidor valida, calcula el total y crea el pedido y el cobro
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createCheckout',
      );
      final response = await callable.call({'items': _buildItems(cart)});
      final data = Map<String, dynamic>.from(response.data as Map);

      // 2. Payment Sheet de Stripe
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['clientSecret'] as String,
          merchantDisplayName: 'Taquería Lety',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      return CheckoutResult(
        CheckoutStatus.paid,
        orderId: data['orderId'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      // Mensajes de zona, dirección o producto: ya vienen en español
      return CheckoutResult(
        CheckoutStatus.failed,
        message: e.message ?? 'No pudimos iniciar el pago',
      );
    } on StripeException catch (e) {
      debugPrint(
        'StripeException: code=${e.error.code} type=${e.error.type} '
        'message=${e.error.message} localized=${e.error.localizedMessage}',
      );
      if (e.error.code == FailureCode.Canceled) {
        return const CheckoutResult(CheckoutStatus.cancelled);
      }
      return CheckoutResult(
        CheckoutStatus.failed,
        message: e.error.localizedMessage ?? 'El pago no se completó',
      );
    } catch (e) {
      debugPrint('Error en checkout: $e');
      return const CheckoutResult(
        CheckoutStatus.failed,
        message: 'Ocurrió un error inesperado. Intenta de nuevo.',
      );
    }
  }
}
