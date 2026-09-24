import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_app/components/widgets/login_required_state.dart';
import 'package:delivery_app/providers/user_provider.dart';
import 'package:delivery_app/theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para el formulario
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController apellidoController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController calleController = TextEditingController();
  final TextEditingController numExtController = TextEditingController();
  final TextEditingController numIntController = TextEditingController();
  final TextEditingController cpController = TextEditingController();
  final TextEditingController coloniaController = TextEditingController();
  final TextEditingController ciudadController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Solicitar los datos a Firestore apenas se monte la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchUserData();
    });
  }

  @override
  void dispose() {
    // Liberar memoria de los controladores
    nombreController.dispose();
    apellidoController.dispose();
    telefonoController.dispose();
    calleController.dispose();
    numExtController.dispose();
    numIntController.dispose();
    cpController.dispose();
    coloniaController.dispose();
    ciudadController.dispose();
    super.dispose();
  }

  // Sincroniza el texto actual del Provider con los controladores del formulario
  void _rellenarControladores(Map<String, dynamic>? datos) {
    if (datos == null) return;

    Map<String, dynamic> direccion = datos['direccion'] ?? {};

    // Solo asignamos si el usuario no ha escrito nada aún (evita sobrescribir mientras escribe)
    if (nombreController.text.isEmpty) {
      nombreController.text = datos['nombre'] ?? '';
    }
    if (apellidoController.text.isEmpty) {
      apellidoController.text = datos['apellido'] ?? '';
    }
    if (telefonoController.text.isEmpty) {
      telefonoController.text = datos['telefono'] ?? '';
    }
    if (calleController.text.isEmpty) {
      calleController.text = direccion['calle'] ?? '';
    }
    if (numExtController.text.isEmpty) {
      numExtController.text = direccion['numero_exterior'] ?? '';
    }
    if (numIntController.text.isEmpty) {
      numIntController.text = direccion['numero_interior'] ?? '';
    }
    if (cpController.text.isEmpty) {
      cpController.text = direccion['codigo_postal'] ?? '';
    }
    if (coloniaController.text.isEmpty) {
      coloniaController.text = direccion['colonia'] ?? '';
    }
    if (ciudadController.text.isEmpty) {
      ciudadController.text = direccion['ciudad'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos de forma activa al UserProvider
    final userProvider = Provider.of<UserProvider>(context);

    // Si es un invitado (sin sesión o sesión anónima) no hay datos que mostrar
    if (userProvider.isGuest) {
      return const LoginRequiredState(
        title: 'Inicia sesión para gestionar tus datos',
        message: 'Aquí podrás guardar tu nombre, teléfono y dirección de envío.',
      );
    }

    // Si está cargando datos de internet, mostramos un indicador
    if (userProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Llenamos los formularios con lo que tenga el Provider (si es que tiene)
    _rellenarControladores(userProvider.userData);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, AppSpacing.fabClearance),
        children: [
          _FormSection(
            title: 'Datos personales',
            icon: Icons.person_outline_rounded,
            children: [
              // Campos básicos
              _buildProfileField(
                Icons.badge_outlined,
                'Nombre',
                nombreController,
              ),
              _buildProfileField(
                Icons.badge_outlined,
                'Apellido',
                apellidoController,
              ),
              _buildProfileField(
                Icons.phone_outlined,
                'Teléfono',
                telefonoController,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _FormSection(
            title: 'Dirección de envío',
            icon: Icons.location_on_outlined,
            children: [
              // Campos de dirección desglosados
              _buildProfileField(
                Icons.signpost_outlined,
                'Calle',
                calleController,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildProfileField(
                      Icons.home_outlined,
                      'No. Ext',
                      numExtController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProfileField(
                      Icons.apartment_outlined,
                      'No. Int',
                      numIntController,
                      isRequired: false,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildProfileField(
                      Icons.markunread_mailbox_outlined,
                      'C.P.',
                      cpController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProfileField(
                      Icons.location_city_outlined,
                      'Colonia',
                      coloniaController,
                    ),
                  ),
                ],
              ),
              _buildProfileField(
                Icons.map_outlined,
                'Ciudad',
                ciudadController,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Botón para Guardar / Actualizar
          FilledButton.icon(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                // Preparamos el mapa de datos recopilados de la UI
                final datosAActualizar = {
                  'nombre': nombreController.text.trim(),
                  'apellido': apellidoController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  'direccion': {
                    'calle': calleController.text.trim(),
                    'numero_exterior': numExtController.text.trim(),
                    'numero_interior': numIntController.text.trim(),
                    'codigo_postal': cpController.text.trim(),
                    'colonia': coloniaController.text.trim(),
                    'ciudad': ciudadController.text.trim(),
                  },
                };

                // Despachamos la actualización mediante el provider
                bool guardadoConExito = await userProvider.updateUserData(
                  datosAActualizar,
                );

                if (context.mounted) {
                  showAppSnackBar(
                    context,
                    guardadoConExito
                        ? 'Datos actualizados correctamente'
                        : 'Error al guardar los datos',
                    kind: guardadoConExito ? SnackKind.success : SnackKind.error,
                  );
                }
              }
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar datos'),
          ),

          const SizedBox(height: 24),

          // Acciones de cuenta
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    _showDialogChangePassword(userProvider);
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Cerrar sesión'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await userProvider.signOut();
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Eliminar cuenta',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () {
                    _showDeleteAccountDialog(userProvider);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar reutilizable para los campos de texto
  Widget _buildProfileField(
    IconData icon,
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'Obligatorio';
          }
          return null;
        },
      ),
    );
  }

  void _showDialogChangePassword(UserProvider userProvider) {
    final passwordFormKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Form(
            key: passwordFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Campo obligatorío ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.length < 6
                      ? 'La contraseña debe tener al menos 6 caracteres'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!passwordFormKey.currentState!.validate()) return;

                try {
                  //Reautenticar por segurida
                  await userProvider.reauthenticateUser(
                    currentPasswordController.text.trim(),
                  );

                  //Cambiar contraseña
                  await userProvider.changePassword(
                    newPasswordController.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Contraseña cambiada con exito'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(UserProvider userProvider) {
    final deleteFormKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '¿Eliminar cuenta definitivamente?',
            style: TextStyle(color: AppColors.danger),
          ),
          content: Form(
            key: deleteFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta acción borrará tu dirección e historial de forma permanente. Introduce tu contraseña para confirmar:',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                if (!deleteFormKey.currentState!.validate()) return;

                try {
                  // 1. Reautenticar
                  await userProvider.reauthenticateUser(
                    passwordController.text.trim(),
                  );
                  // 2. Eliminar de Firestore y Auth
                  await userProvider.deleteUserAccount();

                  if (context.mounted) {
                    Navigator.pop(context); // Cierra diálogo
                    // Aquí puedes redirigir al usuario a la pantalla de Bienvenida/Login si es necesario
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Eliminar permanentemente',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}


class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
