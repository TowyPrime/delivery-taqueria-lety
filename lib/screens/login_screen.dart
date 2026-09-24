import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/components/widgets/google_auth_button.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'main_wrapper.dart';
import 'package:delivery_app/screens/register_screen.dart';
import 'package:delivery_app/screens/permissions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_app/components/widgets/privacy_policy_dialog.dart';

/// Lleva al usuario (típicamente un invitado) a la pantalla de inicio de
/// sesión, limpiando la pila para que "atrás" no regrese a la app.
void goToLogin(BuildContext context) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginScreen()),
    (route) => false,
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showErrorSnackBar('Por favor, llena todos los campos.');
      return;
    }

    setState(() => _isLoading = true);
    setState(() => _obscurePassword = true);
    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      await authProvider.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      _showSuccessSnackBar('Inicio de sesión exitoso');

      _handlePostLogin(); // Maneja la lógica después del inicio de sesión
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al iniciar sesión. Verifica tus datos.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _googleLoading = true;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle();

      if (!mounted) return;

      _showSuccessSnackBar('Inicio de sesión exitoso');
      _handlePostLogin(); // Maneja la lógica después del inicio de sesión
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Ocurrió un error al intentar iniciar sesión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _googleLoading = false;
        });
      }
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void _loginAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      await authProvider.signInAnonymously();

      if (!mounted) return;
      _navigateToHome();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        'No se pudo ingresar como invitado. Intenta de nuevo.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainWrapper()),
    );
  }

  void _showErrorSnackBar(String message) {
    showAppSnackBar(context, message, kind: SnackKind.error);
  }

  void _showSuccessSnackBar(String message) {
    showAppSnackBar(context, message, kind: SnackKind.success);
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PrivacyPolicyDialog(
          onAccept: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('privacy_policy_accepted', true);
            if (context.mounted) {
              Navigator.of(
                context,
              ).pop(); // Cierra el diálogo si el widget ya no está montado

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PermissionsScreen(),
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _handlePostLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final hasAccepted = prefs.getBool('privacy_policy_accepted') ?? false;

    if (hasAccepted) {
      _navigateToHome();
    } else {
      _showPrivacyPolicyDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(size: 132, bordered: true)),
                  const SizedBox(height: 20),
                  const Text(
                    'Taquería Lety',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Desde 2002 · Sabor de casa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
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
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!_isLoading) _login();
                    },
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading && !_googleLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'o',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GoogleAuthButton(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    isLoading: _googleLoading,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginAsGuest,
                    icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                    label: const Text('Ver menú como invitado'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes cuenta?',
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _goToRegister,
                        child: const Text('Crea una aquí'),
                      ),
                    ],
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
