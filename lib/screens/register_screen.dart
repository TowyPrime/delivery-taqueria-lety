import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/providers/auth_provider.dart';
import 'package:delivery_app/screens/login_screen.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _repeatFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureRepeat = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _passwordFocus.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  void _register() async {
    // Validación de campos vacíos
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _repeatPasswordController.text.trim().isEmpty) {
      _showErrorSnackBar('Por favor, llena todos los campos.');
      return;
    }

    // Validación de coincidencia de contraseñas
    if (_passwordController.text.trim() !=
        _repeatPasswordController.text.trim()) {
      _showErrorSnackBar('Las contraseñas no coinciden.');
      return;
    }

    // Activamos la animación de carga
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      await authProvider.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (!mounted) return;
      _showSuccessSnackBar('Usuario registrado con éxito');
      _navigateToLogin();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
          'Error al registrar usuario, vuelve a intentarlo más tarde',
        );
      }
    } finally {
      // Usar 'finally' asegura que la carga se detenga pase lo que pase (éxito o error)
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _showErrorSnackBar(String message) {
    showAppSnackBar(context, message, kind: SnackKind.error);
  }

  void _showSuccessSnackBar(String message) {
    showAppSnackBar(context, message, kind: SnackKind.success);
  }

  Widget _visibilityToggle(bool obscured, VoidCallback onTap) {
    return IconButton(
      tooltip: obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(size: 100, bordered: true)),
                  const SizedBox(height: 16),
                  const Text(
                    'Únete a Taquería Lety',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Crea tu cuenta para pedir en segundos',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _repeatFocus.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: _visibilityToggle(
                        _obscurePassword,
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _repeatPasswordController,
                    focusNode: _repeatFocus,
                    obscureText: _obscureRepeat,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isLoading) _register();
                    },
                    decoration: InputDecoration(
                      labelText: 'Repetir contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: _visibilityToggle(
                        _obscureRepeat,
                        () => setState(() => _obscureRepeat = !_obscureRepeat),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Si está cargando, pasamos null a onPressed para deshabilitar el botón
                  FilledButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Registrar usuario'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
