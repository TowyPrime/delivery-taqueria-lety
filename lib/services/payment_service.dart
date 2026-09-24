import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Resultado de un cobro.
class PaymentResult {
  final bool success;

  /// Id del PaymentIntent de Stripe (para reembolsos). Es null si el cobro
  /// falló o si fue simulado, porque un cobro simulado no tiene id real.
  final String? paymentIntentId;

  const PaymentResult({required this.success, this.paymentIntentId});

  const PaymentResult.failed() : this(success: false);
}

class PaymentService {
  PaymentService._();

  static Future<PaymentResult> makePayment({
    required BuildContext context,
    required double totalAmount,
    String currency = 'MXN',
    bool shouldSuccess = true, // cambiar a falso para simular error
  }) async {
    try {
      //Simulación de retraso de red
      await Future.delayed(const Duration(seconds: 2));

      //Evaluación de resultado simulado
      if (shouldSuccess) {
        debugPrint('Simulación: Pago exitoso por \$$totalAmount $currency');
        // TODO(stripe): con Stripe real, devolver aquí el id del PaymentIntent.
        return const PaymentResult(success: true);
      } else {
        // Simulamos un error típico de Stripe (ej. Tarjeta rechazada)
        throw Exception(
          'La tarjeta de prueba fue rechazada. Fondos insuficientes.',
        );
      }
    } catch (e) {
      debugPrint('Simulación de Error: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
      }
      return const PaymentResult.failed();
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    showAppSnackBar(context, message, kind: SnackKind.error);
  }
}
