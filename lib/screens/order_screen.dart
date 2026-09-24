import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/consumption_chart.dart';
import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/components/widgets/login_required_state.dart';
import 'package:delivery_app/screens/order_detail_widget.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final userId = authProvider.user?.uid;

    if (userId == null || authProvider.needsLogin) {
      return const LoginRequiredState(
        title: 'Inicia sesión para ver tu historial',
        message: 'Aquí verás todos tus pedidos y su estado.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error en StreamBuilder: ${snapshot.error}');
          return const EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Ocurrió un error al obtener tus pedidos',
            message: 'Revisa tu conexión e inténtalo de nuevo.',
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, AppSpacing.fabClearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Tus pedidos'),
              const SizedBox(height: 10),

              // CONDICIÓN DE ESTADO VACÍO
              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppSpacing.radius),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.restaurant_rounded, color: AppColors.warning),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¿Aún no has ordenado con nosotros? ¡Tú te lo estás perdiendo!',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                //Lista de ordenes
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = docs[index].data() as Map<String, dynamic>;
                    final orderId = docs[index].id
                        .substring(0, 6)
                        .toUpperCase();
                    final double total = (order['total'] ?? 0.0).toDouble();
                    final String status = order['status'] ?? 'pendiente';
                    final statusStyle = OrderStatusStyle.of(status);

                    final Timestamp? timeStamp =
                        order['createdAt'] as Timestamp?;
                    String formattedDate = 'Procesando...';
                    if (timeStamp != null) {
                      formattedDate = DateFormat(
                        'dd/MM/yyyy · HH:mm',
                      ).format(timeStamp.toDate());
                    }

                    return Card(
                      child: InkWell(
                        onTap: () {
                          final docId = docs[index].id;

                          bool isEditable =
                              status != 'en preparación' &&
                              status != 'en camino' &&
                              status != 'entregado';

                          _goToOrderDetailScreen(
                            context,
                            docId,
                            order,
                            isEditable,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: statusStyle.background,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  statusStyle.icon,
                                  color: statusStyle.color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pedido #$orderId',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        StatusPill(status: status),
                                        if (order['hasClaim'] == true)
                                          const ClaimBadge(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatMoney(total),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.inkSoft,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),
              const SectionHeader(title: 'Lo que más pides'),
              const SizedBox(height: 10),

              // Contenedor de la gráfica
              Card(
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ConsumptionChart(orders: docs),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToOrderDetailScreen(
    BuildContext context,
    String orderId,
    Map<String, dynamic> orderData,
    bool isEditable,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderDetailWidget(
        orderId: orderId,
        orderData: orderData,
        isEditable: isEditable,
      ),
    );
  }
}
