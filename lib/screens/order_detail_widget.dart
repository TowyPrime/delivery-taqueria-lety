import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/models/claim_model.dart';
import 'package:delivery_app/providers/auth_provider.dart';
import 'package:delivery_app/providers/user_provider.dart';
import 'package:delivery_app/screens/claim_form_screen.dart';
import 'package:delivery_app/services/claim_service.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/providers/order_provider.dart';

class OrderDetailWidget extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailWidget({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final List items = List.from(orderData['items'] ?? []);
    final double total = (orderData['total'] ?? 0.0).toDouble();
    final String status = (orderData['status'] ?? '').toString().toLowerCase();

    final bool isCanceled = status == 'cancelado';
    final bool isDelivered = status == 'entregado';
    final String? claimId = orderData['claimId'] as String?;
    final bool hasClaim =
        orderData['hasClaim'] == true || (claimId?.isNotEmpty ?? false);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusLarge),
          topRight: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tirador visual superior para cerrar el modal deslizando
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Encabezado del Pedido
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${orderId.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(status: status),
            ),
          ),
          const SizedBox(height: 16),

          // Reclamación (si existe) + contenido del pedido
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (hasClaim) ...[
                  const Text(
                    'Tu reclamación',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _ClaimSection(claimId: claimId),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'Contenido del pedido',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'El pedido no tiene productos.',
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    ),
                  )
                else
                  for (final item in items) ...[
                    _ItemCard(item: item),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),

          // Total y acciones
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AmountRow(
                  label: 'Total',
                  value: '${formatMoney(total)} MXN',
                  isTotal: true,
                ),
                const SizedBox(height: 12),
                if (isCanceled)
                  _InfoBox(
                    text: 'Este pedido fue cancelado.',
                    color: AppColors.danger,
                    background: AppColors.dangerSoft,
                  )
                else if (hasClaim)
                  const _InfoBox(
                    text: 'Este pedido ya tiene una reclamación en curso.',
                    color: AppColors.warning,
                    background: AppColors.accentSoft,
                  )
                else if (isDelivered)
                  // Pedido entregado: se reclama (el pedido conserva su estado).
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Solicitar devolución'),
                    onPressed: () => _openClaimForm(context, total, status),
                  )
                else if (status == 'pendiente')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar pedido'),
                    onPressed: () async {
                      // Preguntar confirmación
                      bool confirm = await _showConfirmDialog(context);
                      if (!confirm || !context.mounted) return;

                      // Capturar el rootContext antes de realizar operaciones asíncronas
                      final rootContext = Navigator.of(
                        context,
                        rootNavigator: true,
                      ).context;

                      try {
                        // Cancelar primero (antes de cerrar el modal)
                        await orderProvider.cancelOrder(orderId);

                        // Si sale bien, cerramos el modal de detalle
                        if (!context.mounted) return;
                        Navigator.pop(context);

                        // Mostrar el mensaje de éxito
                        showAppSnackBar(
                          rootContext,
                          'Pedido cancelado. Tu reembolso llegará en 5 a 10 días hábiles.',
                          duration: const Duration(seconds: 5),
                        );
                      } catch (e) {
                        // Si falla, el modal NO se cierra y mostramos el error
                        if (rootContext.mounted) {
                          showAppSnackBar(
                            rootContext,
                            e.toString().replaceFirst('Exception: ', ''),
                            kind: SnackKind.error,
                            duration: const Duration(seconds: 5),
                          );
                        }
                      }
                    },
                  )
                else if ([
                  'preparando',
                  'en preparación',
                  'en camino',
                ].contains(status))
                  const _InfoBox(
                    text:
                        'Tu pedido ya está en preparación y no puede cancelarse',
                    color: AppColors.warning,
                    background: AppColors.dangerSoft,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cierra el detalle y abre el formulario de reclamación.
  void _openClaimForm(BuildContext context, double total, String status) {
    final auth = context.read<AppAuthProvider>();
    final phone = context.read<UserProvider>().userData?['telefono'] as String?;
    final navigator = Navigator.of(context);

    navigator.pop(); // cierra el detalle
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ClaimFormScreen(
          orderId: orderId,
          orderTotal: total,
          orderStatus: status,
          userId: auth.user?.uid ?? '',
          userName: auth.user?.displayName ?? auth.user?.email ?? 'cliente',
          contactPhone: phone,
        ),
      ),
    );
  }

  // Diálogo de confirmación para cancelar pedido
  Future<bool> _showConfirmDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Cancelar pedido?'),
            content: const Text(
              '¿Deseas proseguir con la cancelación de este pedido?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                child: const Text('No, volver'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Sí, cancelar'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Estado en vivo de la reclamación del pedido.
class _ClaimSection extends StatelessWidget {
  final String? claimId;

  const _ClaimSection({required this.claimId});

  @override
  Widget build(BuildContext context) {
    if (claimId == null || claimId!.isEmpty) {
      return const _InfoBox(
        text: 'Tu reclamación fue registrada. Pronto verás aquí su estado.',
        color: AppColors.warning,
        background: AppColors.accentSoft,
      );
    }

    return StreamBuilder<ClaimModel?>(
      stream: context.read<ClaimService>().streamClaim(claimId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _InfoBox(
            text: 'No pudimos cargar tu reclamación en este momento.',
            color: AppColors.danger,
            background: AppColors.dangerSoft,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final claim = snapshot.data;
        if (claim == null) {
          return const _InfoBox(
            text: 'Tu reclamación fue registrada. Pronto verás aquí su estado.',
            color: AppColors.warning,
            background: AppColors.accentSoft,
          );
        }
        return ClaimSummaryCard(claim: claim);
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  final dynamic item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final double itemPrice = (item['price'] ?? 0.0).toDouble();
    final int quantity = (item['quantity'] as num? ?? 1).toInt();
    // Los platos guardan sus ingredientes como "products" (carrito) o
    // "details" (pedido modificado).
    final List parts = List.from(
      item['products'] ?? item['details'] ?? const [],
    );
    final List contents = List.from(item['contents'] ?? const []);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$quantity×',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Producto',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final c in contents)
                    (Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '• $c',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    )),
                  for (final part in parts)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${part['quantity'] ?? 1}× ${part['name'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatMoney(itemPrice * quantity),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _InfoBox({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
