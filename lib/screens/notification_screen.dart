import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/models/order_model.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // Mapeamos el string de la base de datos a un valor numérico para la UI
  int _getStatusStep(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return 0;
      case 'preparando':
      case 'en preparación':
        return 1;
      case 'en camino':
        return 2;
      case 'entregado':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const EmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'Inicia sesión para ver tus notificaciones',
      );
    }

    return StreamBuilder<List<OrderModel>>(
      stream: orderProvider.streamActiveOrders(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Error al conectar con el servidor',
            message: 'Revisa tu conexión e inténtalo de nuevo.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        //Si el usuario no tiene pedidos activos
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No tienes pedidos en curso',
            message: 'Cuando hagas un pedido, aquí verás su progreso.',
          );
        }
        //Si encontramos pedidos activos
        final OrderModel activeOrder = snapshot.data!.first;
        final int currentStep = _getStatusStep(activeOrder.status);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, AppSpacing.fabClearance),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido #${activeOrder.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Total: ${formatMoney(activeOrder.total)} MXN',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Progreso en tiempo real'),
            const SizedBox(height: 16),
            //Linea de tiempo
            _StepTile(
              title: 'Pedido pendiente',
              subtitle: 'Esperando confirmación de Taquería Lety.',
              icon: Icons.receipt_long_rounded,
              isActive: currentStep >= 0,
              isCurrent: currentStep == 0,
              isLast: false,
              nextIsActive: currentStep >= 1,
            ),
            _StepTile(
              title: 'En cocina',
              subtitle: '¡Tus tacos se están preparando!',
              icon: Icons.soup_kitchen_rounded,
              isActive: currentStep >= 1,
              isCurrent: currentStep == 1,
              isLast: false,
              nextIsActive: currentStep >= 2,
            ),
            _StepTile(
              title: 'Repartidor en camino',
              subtitle: 'El repartidor va rumbo a tu domicilio.',
              icon: Icons.directions_bike_rounded,
              isActive: currentStep >= 2,
              isCurrent: currentStep == 2,
              isLast: false,
              nextIsActive: currentStep >= 3,
            ),
            _StepTile(
              title: 'Entregado',
              subtitle: '¡Listo! ¡Buen provecho!',
              icon: Icons.check_circle_rounded,
              isActive: currentStep >= 3,
              isCurrent: currentStep == 3,
              isLast: true,
              nextIsActive: false,
            ),
          ],
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final bool isCurrent;
  final bool isLast;
  final bool nextIsActive;

  const _StepTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.isCurrent,
    required this.isLast,
    required this.nextIsActive,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppColors.primary : AppColors.borderStrong;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary
                      : color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isCurrent ? Colors.white : color,
                  size: 22,
                ),
              ),
              // Conector hacia el siguiente paso (no se dibuja en el último)
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: nextIsActive
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isActive ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isActive
                          ? AppColors.inkSoft
                          : AppColors.inkSoft.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
