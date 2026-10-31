import 'package:delivery_app/models/claim_model.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatMoney(num value) => '\$${value.toStringAsFixed(2)}';

/// Logo de la taquería. Es el único lugar que conoce la ruta del asset.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool bordered;

  const BrandLogo({super.key, this.size = 96, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: bordered ? Border.all(color: AppColors.border, width: 2) : null,
        boxShadow: bordered
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/ic_logo_round.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.primarySoft,
            child: Icon(
              Icons.restaurant_rounded,
              color: AppColors.primary,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vacío reutilizable: icono, título, texto y (opcional) una acción.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Título de sección con acción opcional a la derecha.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Imagen de producto con placeholder cálido y estado de carga.
class ProductThumb extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double radius;
  final IconData fallbackIcon;

  const ProductThumb({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 14,
    this.fallbackIcon = Icons.restaurant_rounded,
  });

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.accentSoft,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: AppColors.accent.withValues(alpha: 0.9),
        size: 30,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url.isEmpty
            ? _placeholder()
            : Image.network(
                url,
                width: width,
                height: height,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.accentSoft,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => _placeholder(),
              ),
      ),
    );
  }
}

/// Selector de cantidad compacto (− 2 +).
class QuantityStepper extends StatelessWidget {
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final bool large;

  const QuantityStepper({
    super.key,
    required this.value,
    this.onDecrement,
    this.onIncrement,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final double box = large ? 44 : 34;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(box),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            size: box,
            onPressed: onDecrement,
          ),
          SizedBox(
            width: large ? 44 : 30,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: large ? 20 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            size: box,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, required this.size, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: size * 0.56,
        onPressed: onPressed,
        color: AppColors.primary,
        disabledColor: AppColors.borderStrong,
        icon: Icon(icon),
      ),
    );
  }
}

/// Etiqueta de color con el estado de un pedido.
class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = OrderStatusStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila "etiqueta ........ valor" usada en resúmenes de dinero.
class AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 17 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              color: isTotal ? AppColors.ink : AppColors.inkSoft,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 20 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
              color: isTotal ? AppColors.primary : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de color con el estado de una reclamación.
class ClaimStatusPill extends StatelessWidget {
  final ClaimStatus status;

  const ClaimStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, Color background, IconData icon) = switch (status) {
      ClaimStatus.abierta => (
        AppColors.warning,
        AppColors.accentSoft,
        Icons.schedule_rounded,
      ),
      ClaimStatus.enRevision => (
        AppColors.info,
        AppColors.infoSoft,
        Icons.manage_search_rounded,
      ),
      ClaimStatus.resuelta => (
        AppColors.success,
        AppColors.successSoft,
        Icons.check_circle_rounded,
      ),
      ClaimStatus.rechazada => (
        AppColors.danger,
        AppColors.dangerSoft,
        Icons.cancel_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Insignia pequeña para tarjetas de pedido que ya tienen una reclamación.
class ClaimBadge extends StatelessWidget {
  const ClaimBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.report_problem_outlined,
            size: 14,
            color: AppColors.warning,
          ),
          SizedBox(width: 5),
          Text(
            'Con reclamación',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de una reclamación: folio, estado, motivo y respuesta del negocio.
class ClaimSummaryCard extends StatelessWidget {
  final ClaimModel claim;

  const ClaimSummaryCard({super.key, required this.claim});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reclamación #${claim.folio}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ClaimStatusPill(status: claim.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${claim.type.label} · ${DateFormat('dd/MM/yyyy').format(claim.createdAt)}',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            if (claim.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                claim.reason,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ],
            if (claim.resolution != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Respuesta de Taquería Lety',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claim.resolution!,
                      style: const TextStyle(fontSize: 14, height: 1.35),
                    ),
                    if (claim.refundAmount != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reembolso: ${formatMoney(claim.refundAmount!)} MXN',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
