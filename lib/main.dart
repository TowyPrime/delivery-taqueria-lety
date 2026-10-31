import 'package:delivery_app/firebase_options.dart';
import 'package:delivery_app/providers/auth_provider.dart';
import 'package:delivery_app/providers/cart_provider.dart';
import 'package:delivery_app/providers/order_provider.dart';
import 'package:delivery_app/providers/user_provider.dart';
import 'package:delivery_app/screens/login_screen.dart';
import 'package:delivery_app/services/claim_service.dart';
import 'package:delivery_app/services/google_auth_service.dart';
import 'package:delivery_app/services/notification_service.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check: en release usa Play Integrity / App Attest; en depuración, el
  // proveedor de depuración (su token se registra en la consola de Firebase).
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
  } catch (e) {
    debugPrint('No se pudo activar App Check: $e');
  }

  await dotenv.load(fileName: ".env");

  await GoogleAuthService.initialize();

  await NotificationService.initialize();

  Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  await Stripe.instance.applySettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        Provider(create: (_) => ClaimService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taquería Lety',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
