import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app/components/widgets/announcement_card.dart';

class DynamicAnnouncementBanner extends StatelessWidget {
  const DynamicAnnouncementBanner({super.key});

  // Mapeo del color base
  Color _getColor(String? key) {
    switch (key?.toLowerCase().trim()) {
      case 'red':
        return Colors.red.shade700;
      case 'orange':
        return Colors.orange.shade800;
      case 'green':
        return Colors.green.shade800;
      case 'blue':
        return Colors.blue.shade700;
      case 'purple':
        return Colors.purple.shade700;
      case 'teal':
        return Colors.teal.shade700;
      case 'amber':
        return Colors.amber.shade800;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  // Mapeo del icono
  IconData _getIcon(String? name) {
    switch (name?.toLowerCase().trim()) {
      case 'celebration':
        return Icons.celebration;
      case 'access_time_filled':
      case 'time':
        return Icons.access_time_filled;
      case 'local_offer':
      case 'offer':
        return Icons.local_offer;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'delivery':
        return Icons.delivery_dining;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.campaign;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String announcementDocId = 'il1RmwlalbBYyX7SIrBP';

    // Verificamos si el mes actual es septiembre
    final bool isSeptember = DateTime.now().month == 9;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .doc(announcementDocId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data();
        if (data == null) return const SizedBox.shrink();

        final bool isVisible = data['isVisible'] ?? true;
        if (!isVisible) return const SizedBox.shrink();

        final String title = data['title'] ?? '';
        final String subtitle = data['subtitle'] ?? '';

        if (title.isEmpty && subtitle.isEmpty) {
          return const SizedBox.shrink();
        }

        // Si es septiembre, usamos un contenedor con borde tricolor
        if (isSeptember) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Container(
              // Usamos un BoxDecoration para crear el borde tricolor (Bandera de México)
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  19.0,
                ), // 16 de la tarjeta + 3 del grosor del borde
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF006341), // Verde bandera
                    Colors.white, // Blanco
                    Color(0xFFCE1126), // Rojo bandera
                  ],
                  stops: [0.33, 0.33, 0.66], // Distribución de los colores
                ),
              ),
              padding: const EdgeInsets.all(3.0), // Grosor del borde tricolor
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).scaffoldBackgroundColor, // Fondo interno para que no tape el diseño de la tarjeta
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: AnnouncementCard(
                  title: title,
                  subtitle: subtitle,
                  margin: EdgeInsets.zero,
                  baseColor: _getColor(data['color'] as String?),
                  icon: _getIcon(data['iconName'] as String?),
                ),
              ),
            ),
          );
        }

        // Comportamiento normal para el resto del año
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: AnnouncementCard(
            title: title,
            subtitle: subtitle,
            margin: EdgeInsets.zero,
            baseColor: _getColor(data['color'] as String?),
            icon: _getIcon(data['iconName'] as String?),
          ),
        );
      },
    );
  }
}
