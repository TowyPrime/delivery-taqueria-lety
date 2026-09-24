import 'package:delivery_app/providers/auth_provider.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/widgets/home/product_section.dart';
import 'package:delivery_app/components/widgets/dynamic_announcement_banner.dart';

class HomeScaffold extends StatelessWidget {
  const HomeScaffold({
    super.key,
    required this.authProvider,
    required this.onGoToMenu,
    required this.onGotoCart,
  });

  final AppAuthProvider authProvider;
  final VoidCallback onGoToMenu;
  final VoidCallback onGotoCart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          8,
          AppSpacing.page,
          AppSpacing.fabClearance,
        ),
        child: ScreenHomeColumn(
          authProvider: authProvider,
          onGoToMenu: onGoToMenu,
          onGotoCart: onGotoCart,
        ),
      ),
    );
  }
}

class ScreenHomeColumn extends StatelessWidget {
  const ScreenHomeColumn({
    super.key,
    required this.authProvider,
    required this.onGoToMenu,
    required this.onGotoCart,
  });

  final AppAuthProvider authProvider;
  final VoidCallback onGoToMenu;
  final VoidCallback onGotoCart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeCard(authProvider: authProvider, onGoToMenu: onGoToMenu),
        const SizedBox(height: 16),

        //Tablero de Anuncios / Avisos Festivos
        const DynamicAnnouncementBanner(),

        //Sección de Paquetes
        ProductSection(
          title: 'Promociones especiales',
          query: FirebaseFirestore.instance
              .collection('products')
              .where('isPackage', isEqualTo: true),
          onGotoCart: onGotoCart,
        ),

        const SizedBox(height: 24),

        //Sección de Productos Destacados
        ProductSection(
          title: 'Los favoritos de la casa',
          query: FirebaseFirestore.instance
              .collection('products')
              .where('isFeatured', isEqualTo: true),
          onGotoCart: onGotoCart,
          onSeeAll: onGoToMenu,
          isFeatured: true,
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final AppAuthProvider authProvider;
  final VoidCallback onGoToMenu;

  const _WelcomeCard({required this.authProvider, required this.onGoToMenu});

  @override
  Widget build(BuildContext context) {
    final String firstName =
        (authProvider.user?.displayName ?? '').trim().split(' ').first;
    final String greeting = firstName.isNotEmpty ? '¡Hola, $firstName!' : '¡Hola!';

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -18,
            child: Icon(
              Icons.dinner_dining_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '¿Se te antojan\nunos tacos?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onGoToMenu,
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                  label: const Text('Ver el menú'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
