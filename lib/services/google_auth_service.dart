import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _initialized = false;

  static StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  static GoogleSignInAccount? _currentUser;

  static Future<void> initialize() async {
    if (_initialized) return;

    await _googleSignIn.initialize(
      serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
    );

    _authSubscription = _googleSignIn.authenticationEvents.listen(
      _handleAuthenticationEvent,
      onError: _handleAuthenticationError,
    );

    _initialized = true;
  }

  static void _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) {
    _currentUser = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
  }

  static void _handleAuthenticationError(Object error) {
    _currentUser = null;
    debugPrint('Error en el flujo de GoogleAuth: $error');
  }

  static Future<GoogleSignInAccount?> signIn() async {
    if (_googleSignIn.supportsAuthenticate()) {
      await _googleSignIn.authenticate();
      return _currentUser;
    } else {
      throw UnsupportedError(
        'Este dispositivo o plataforma no soporta el método de autenticación actual.',
      );
    }
  }

  //Cerrar sesión
  static Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
  }

  /// Obtiene el usuario actual si ya ha iniciado sesión
  static GoogleSignInAccount? get currentUser => _currentUser;

  static void dispose() {
    _authSubscription?.cancel();
  }
}
