import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  /// Invitado = sin sesión, o sesión anónima (el acceso "Ver menú como invitado").
  bool get isGuest {
    final User? user = _auth.currentUser;
    return user == null || user.isAnonymous;
  }

  // Carga los datos al iniciar la pantalla o la app
  Future<void> fetchUserData() async {
    final User? user = _auth.currentUser;
    // Un invitado no tiene perfil guardado: evitamos consultar Firestore.
    if (user == null || user.isAnonymous) {
      _userData = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>?;
      } else {
        _userData = null; // No tiene datos complementarios aún
      }
    } catch (e) {
      debugPrint("Error al obtener usuario: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Registra o actualiza la información en Firestore
  Future<bool> updateUserData(Map<String, dynamic> data) async {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('users').doc(user.uid).set(
        {
          'uid': user.uid,
          ...data,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      
      // Actualiza el estado local de la app de inmediato
      if (_userData == null) {
        _userData = data;
      } else {
        // Combinar mapas de forma segura incluyendo mapas internos como dirección
        data.forEach((key, value) {
          if (value is Map && _userData![key] is Map) {
            _userData![key].addAll(value);
          } else {
            _userData![key] = value;
          }
        });
      }
      return true;
    } catch (e) {
      debugPrint("Error al guardar usuario: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cierra sesión 
  Future<void> signOut() async {
    await _auth.signOut();
    _userData = null;
    notifyListeners();
  }

  Future<void> changePassword(String newPassword)async{
    final User? user = _auth.currentUser;
    if(user == null) throw Exception("No hay un usuario autenticado.");

    try{
        await user.updatePassword(newPassword);
    }on FirebaseAuthException catch(e){
      throw _handleAuthException(e);
      
    }
  }

  //Reautenticar usuario
  Future<void> reauthenticateUser(String currentPassword) async{
    final User? user = _auth.currentUser;
    if(user == null || user.email == null) throw Exception("Usuario no válido.");

    try{
        AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
    }on FirebaseAuthException catch(e){
      throw _handleAuthException(e);
    }
  }

  //Eliminar cuenta
  Future<void> deleteUserAccount()async{
    final User? user = _auth.currentUser;
    if(user == null) throw Exception('No hay usuario autenticado');

    final String uid = user.uid;

    try{
          //Borrar datos de usuario
          await _db.collection('users').doc(uid).delete();

          //borrar cuenta de autenticación
          await user.delete();

          //Limpiar estado
          _userData = null;
          notifyListeners();
    }on FirebaseAuthException catch(e){
      throw _handleAuthException(e);

    }
  }

}

// Manejador de errores amigable para el usuario
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'La contraseña actual es incorrecta.';
      case 'weak-password':
        return 'La nueva contraseña es demasiado débil.';
      case 'requires-recent-login':
        return 'Por seguridad, necesitas reautenticarte primero.';
      default:
        return e.message ?? 'Ocurrió un error inesperado.';
    }
  }