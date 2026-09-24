import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/providers/user_provider.dart';
import 'package:delivery_app/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onNavigateToAdmin;
  final VoidCallback? onbackToHome;

  const ProfileScreen({super.key, this.onNavigateToAdmin, this.onbackToHome});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isUploadingImage = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = _auth.currentUser?.photoURL;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.userData == null && !userProvider.isLoading) {
        userProvider.fetchUserData();
      }
    });
  }

  String _formatAddress(Map<String, dynamic>? data) {
    if (data == null || data['direccion'] == null) {
      return 'Domicilio no registrado';
    }

    final direccion = data['direccion'] as Map<String, dynamic>;

    final calle = (direccion['calle'] ?? '').toString().trim();
    final numExt = (direccion['numero_exterior'] ?? '').toString().trim();
    final numInt = (direccion['numero_interior'] ?? '').toString().trim();
    final colonia = (direccion['colonia'] ?? '').toString().trim();
    final cp = (direccion['codigo_postal'] ?? '').toString().trim();
    final ciudad = (direccion['ciudad'] ?? '').toString().trim();

    List<String> lineaCalle = [];
    if (calle.isNotEmpty) lineaCalle.add(calle);
    if (numExt.isNotEmpty) lineaCalle.add('#$numExt');
    if (numInt.isNotEmpty) lineaCalle.add('Int. $numInt');

    final String calleCompleta = lineaCalle.join(' ');

    List<String> partes = [];
    if (calleCompleta.isNotEmpty) partes.add(calleCompleta);
    if (colonia.isNotEmpty) partes.add('Col. $colonia');
    if (cp.isNotEmpty) partes.add('C.P. $cp');
    if (ciudad.isNotEmpty) partes.add(ciudad);

    return partes.isEmpty ? 'Domicilio no disponible' : partes.join(', ');
  }

  // Modal para seleccionar origen o cancelar
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.close_rounded,
                  color: AppColors.inkSoft,
                ),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      // Si el usuario cancela o regresa sin elegir imagen, se ignora sin error
      if (pickedFile == null) return;

      final File file = File(pickedFile.path);

      final int fileSizeInBytes = await file.length();
      if (fileSizeInBytes > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La imagen supera el límite de 2 MB')),
          );
        }
        return;
      }

      setState(() => _isUploadingImage = true);

      final storageRef = _storage.ref().child('users/${user.uid}/profile.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = await storageRef.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      if (!mounted) return;

      await user.updatePhotoURL(downloadUrl);
      if (mounted) {
        await context.read<UserProvider>().updateUserData({
          'photoUrl': downloadUrl,
        });
      }

      setState(() {
        _photoUrl = downloadUrl;
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada con éxito')),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la imagen: $e')),
        );
      }
    }
  }

  // Diálogo de cambio de contraseña con reautenticación
  Future<void> _showChangePasswordDialog() async {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool isProcessing = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    // Bordes, relleno y colores vienen del InputDecorationTheme global.
    InputDecoration buildInputDecoration({
      required String labelText,
      required IconData prefixIcon,
      required bool isObscured,
      required VoidCallback onToggleVisibility,
    }) {
      return InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon, size: 22),
        suffixIcon: IconButton(
          tooltip: isObscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(
            isObscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: onToggleVisibility,
        ),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar contraseña'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: currentPasswordCtrl,
                        obscureText: obscureCurrent,
                        decoration: buildInputDecoration(
                          labelText: 'Contraseña actual',
                          prefixIcon: Icons.lock_outline,
                          isObscured: obscureCurrent,
                          onToggleVisibility: () {
                            setDialogState(
                              () => obscureCurrent = !obscureCurrent,
                            );
                          },
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Ingresa tu contraseña actual'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordCtrl,
                        obscureText: obscureNew,
                        decoration: buildInputDecoration(
                          labelText: 'Nueva contraseña',
                          prefixIcon: Icons.lock_reset,
                          isObscured: obscureNew,
                          onToggleVisibility: () {
                            setDialogState(() => obscureNew = !obscureNew);
                          },
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Ingresa la nueva contraseña';
                          }
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordCtrl,
                        obscureText: obscureConfirm,
                        decoration: buildInputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                          prefixIcon: Icons.lock_reset,
                          isObscured: obscureConfirm,
                          onToggleVisibility: () {
                            setDialogState(
                              () => obscureConfirm = !obscureConfirm,
                            );
                          },
                        ),
                        validator: (v) {
                          if (v != newPasswordCtrl.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isProcessing = true);
                          final userProvider = context.read<UserProvider>();

                          try {
                            // Reautenticar
                            await userProvider.reauthenticateUser(
                              currentPasswordCtrl.text.trim(),
                            );
                            // Cambiar contraseña
                            await userProvider.changePassword(
                              newPasswordCtrl.text.trim(),
                            );

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Contraseña actualizada con éxito',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                  child: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );

    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = _auth.currentUser;
    final String formattedAddress = _formatAddress(userProvider.userData);
    final String displayName = (user?.displayName ?? '').trim();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, AppSpacing.fabClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto de perfil
            Center(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.primarySoft,
                      backgroundImage: _photoUrl != null
                          ? NetworkImage(_photoUrl!)
                          : null,
                      child: _photoUrl == null && !_isUploadingImage
                          ? const Icon(
                              Icons.person_rounded,
                              size: 60,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                  ),
                  if (_isUploadingImage)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white, width: 3),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isUploadingImage
                            ? null
                            : _showImagePickerOptions,
                        child: const Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (displayName.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Tarjeta con datos del usuario
            if (user != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Correo electrónico',
                        value: user.email ?? 'Sin correo registrado',
                      ),
                      const Divider(),
                      if (userProvider.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: LinearProgressIndicator(),
                        )
                      else
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Domicilio',
                          value: formattedAddress,
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 22),

            // Botón Modificar Datos
            FilledButton.icon(
              onPressed: () => widget.onNavigateToAdmin?.call(),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Modificar mis datos'),
            ),

            const SizedBox(height: 12),

            // Botón Cambiar Contraseña
            OutlinedButton.icon(
              onPressed: _showChangePasswordDialog,
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Cambiar contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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
