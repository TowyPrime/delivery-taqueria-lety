import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app/components/widgets/announcement_card.dart';

class _SeassonStyle {
  final Color? baseColor;
  final List<Color> borderColors;

  final bool stripes;

  const _SeassonStyle({
    this.baseColor,
    required this.borderColors,
    this.stripes = false,
  });
}

class DynamicAnnouncementBanner extends StatelessWidget {
  final int? month;
  const DynamicAnnouncementBanner({super.key, this.month});

  //Meses con decoraci+on especial
  static const Map<int, _SeassonStyle> _seassons = {
    //Septiembre
    9: _SeassonStyle(
      borderColors: [Color(0xFF006341), Colors.white, Color(0xFFCE1126)],
      stripes: true,
    ),

    //Octubre
    10: _SeassonStyle(
      baseColor: Color(0xFFE65100),
      borderColors: [Color(0xFFFF6D00), Color(0xFF6A1B9A), Color(0xFF212121)],
    ),

    //Noviembre
    11: _SeassonStyle(
      baseColor: Color(0xFFF57C00),
      borderColors: [Color(0xFFFF9800), Color(0xFFC2185B), Color(0xFF7B1FA2)],
    ),

    //Diciembre
    12: _SeassonStyle(
      baseColor: Color(0xFFC62828),
      borderColors: [Color(0xFFC62828), Color(0xFF1B5E20), Color(0xFFFFC107)],
    ),
  };

  LinearGradient _borderGradient(_SeassonStyle style) {
    if (style.stripes) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: style.borderColors,
      );
    }
    // Cada color ocupa 1/n del borde con corte seco.
    final int n = style.borderColors.length;
    final List<Color> colors = [];
    final List<double> stops = [];
    for (var i = 0; i < n; i++) {
      colors
        ..add(style.borderColors[i])
        ..add(style.borderColors[i]);
      stops
        ..add(i / n)
        ..add((i + 1) / n);
    }
    return LinearGradient(colors: colors, stops: stops);
  }

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

    final _SeassonStyle? season = _seassons[month ?? DateTime.now().month];

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
          return SizedBox.shrink();
        }

        final Widget card = AnnouncementCard(
          title: title,
          subtitle: subtitle,
          margin: EdgeInsets.zero,
          baseColor: season?.baseColor ?? _getColor(data['color'] as String?),
          icon: _getIcon(data['iconName'] as String?),
        );

        if (season == null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: card,
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19.0),
              gradient: _borderGradient(season),
            ),
            padding: const EdgeInsets.all(3.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: card,
            ),
          ),
        );
      },
    );
  }
}
