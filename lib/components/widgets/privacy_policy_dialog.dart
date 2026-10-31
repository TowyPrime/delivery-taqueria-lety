import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyDialog extends StatelessWidget {
  final VoidCallback onAccept;

  const PrivacyPolicyDialog({super.key, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(child: Text('Aviso de privacidad')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Para ofrecerte el servicio de entrega a domicilio, requerimos recopilar y tratar los siguientes datos personales:',
              ),
              SizedBox(height: 12),
              _ItemDato(
                icon: Icons.person_outline,
                texto: 'Nombre completo para identificar tu pedido.',
              ),
              _ItemDato(
                icon: Icons.email_outlined,
                texto: 'Correo electrónico para confirmaciones y recibos.',
              ),
              _ItemDato(
                icon: Icons.phone_outlined,
                texto: 'Teléfono para contactarte sobre tu entrega.',
              ),
              _ItemDato(
                icon: Icons.home_outlined,
                texto: 'Dirección de entrega para calcular cobertura y envíos.',
              ),
              _ItemDato(
                icon: Icons.my_location_outlined,
                texto:
                    'Tu ubicación, solo si pulsas "Usar mi ubicación", para llenar tu dirección.',
              ),
              _ItemDato(
                icon: Icons.notifications_outlined,
                texto:
                    'Un identificador de tu teléfono para avisarte del estado de tu pedido.',
              ),
              SizedBox(height: 12),
              Text(
                'Tus datos están protegidos y únicamente se utilizarán para la gestión y entrega de tus pedidos. '
                'El pago lo procesa Stripe: nosotros no guardamos los datos de tu tarjeta. '
                'Puedes eliminar tu cuenta en cualquier momento desde "Mis datos".',
                style: TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}

class _ItemDato extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _ItemDato({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                texto,
                style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
