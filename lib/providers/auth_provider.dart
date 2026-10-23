import 'package:delivery_app/services/google_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AppAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;

  AppAuthProvider() {
    // Escucha activamente si el estado de la sesión cambia (ej. si el usuario cierra sesión)
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Getters útiles para tus pantallas
  User? get user => _user;
  bool get isLoggedIn => _user != null && !_user!.isAnonymous;
  bool get isGuest => _user != null && _user!.isAnonymous;

  /// Verdadero si no hay sesión real: invitado (anónimo) o sin usuario.
  /// Es lo que decide si se muestran las opciones de cuenta o "Iniciar sesión".
  bool get needsLogin => _user == null || _user!.isAnonymous;
  String? get currentUserId => _auth.currentUser?.uid;

  //Inicio como invitado
  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      rethrow;
    }
  }

  //Regitro con google
  Future<void> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleAuthService.signIn();

    if (googleUser == null) {
      throw Exception("no se pudo inicir sesión con Google");
    }

    final String? idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw Exception("Google no devolvió el token de identidad");
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
  }

  //Inicio con correo y contraseña
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  //Registro de usuario
  Future<void> registerWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  //Cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();

      GoogleAuthService.signOut();

      notifyListeners();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      rethrow;
    }
  }
}
