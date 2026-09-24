import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main_wrapper.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isRequesting = false;

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequesting = true);

    // Lista actualizada incluyendo notificaciones
    final List<Permission> permissions = [
      Permission.locationWhenInUse,
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.notification, // <--- NUEVO: Permiso de notificaciones
    ];

    // Solicita todos los permisos en lote
    final Map<Permission, PermissionStatus> statuses = await permissions
        .request();

    if (!mounted) return;
    setState(() => _isRequesting = false);

    // Verificamos si algún permiso crítico fue denegado permanentemente
    final bool permanentlyDenied = statuses.values.any(
      (status) => status.isPermanentlyDenied,
    );

    if (permanentlyDenied) {
      _showSettingsDialog();
    } else {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainWrapper()),
      (route) => false,
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permisos requeridos'),
        content: const Text(
          'Algunos permisos fueron denegados de forma permanente. '
          'Para que la app funcione correctamente, por favor actívalos desde los ajustes del sistema.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Permisos necesarios',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Para ofrecerte la mejor experiencia en la app, necesitamos acceso a las siguientes funciones:',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionItem(
                      icon: Icons.location_on_outlined,
                      title: 'Ubicación',
                      description:
                          'Para calcular tiempos de entrega y direcciones precisas.',
                    ),
                    // NUEVO ITEM DE NOTIFICACIONES EN LA UI
                    _buildPermissionItem(
                      icon: Icons.notifications_outlined,
                      title: 'Notificaciones',
                      description:
                          'Para avisarte al instante cuando el estado de tu pedido cambie.',
                    ),
                    _buildPermissionItem(
                      icon: Icons.camera_alt_outlined,
                      title: 'Cámara',
                      description:
                          'Para tomar fotos de comprobantes o actualizar tu perfil.',
                    ),
                    _buildPermissionItem(
                      icon: Icons.photo_library_outlined,
                      title: 'Galería de imágenes',
                      description:
                          'Para adjuntar imágenes existentes desde tu dispositivo.',
                    ),
                    _buildPermissionItem(
                      icon: Icons.folder_open_outlined,
                      title: 'Almacenamiento',
                      description:
                          'Para guardar recibos y datos necesarios fuera de línea.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isRequesting ? null : _requestAllPermissions,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: _isRequesting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Continuar y permitir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
