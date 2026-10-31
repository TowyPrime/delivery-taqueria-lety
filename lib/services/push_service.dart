import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:delivery_app/services/notification_service.dart';

class PushService {
  static String? _currentToken;
  static StreamSubscription<String>? _refreshSub;
  static StreamSubscription<RemoteMessage>? _messageSub;

  /// Inicializa los push si hay un usuario con cuenta (no anónimo).
  /// Se puede llamar varias veces: cancela las escuchas anteriores.
  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      debugPrint('Push: sin usuario con cuenta, no se registra el token');
      return;
    }

    try {
      debugPrint('Push: iniciando para ${user.uid}');
      await _cancelSubscriptions();

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('Push: permiso = ${settings.authorizationStatus}');

      final token = await messaging.getToken();
      debugPrint('Push: token = ${token == null ? 'NULO' : 'obtenido'}');
      if (token != null) {
        _currentToken = token;
        await _saveTokenToFirestore(user.uid, token);
      }

      _refreshSub = messaging.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && !currentUser.isAnonymous) {
          await _saveTokenToFirestore(currentUser.uid, newToken);
        }
      });

      // En primer plano Android no muestra el push: lo mostramos nosotros
      _messageSub = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        NotificationService.showNotification(
          id: (message.data['orderId'] ?? notification.hashCode).hashCode,
          title: notification.title ?? 'Taquería Lety',
          body: notification.body ?? '',
        );
      });
    } catch (e) {
      debugPrint('Error al iniciar los push: $e');
    }
  }

  static Future<void> _cancelSubscriptions() async {
    await _refreshSub?.cancel();
    await _messageSub?.cancel();
    _refreshSub = null;
    _messageSub = null;
  }

  static Future<void> _saveTokenToFirestore(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
            'platform': defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'android',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      debugPrint('Push: token guardado en Firestore');
    } catch (e) {
      debugPrint('Error al guardar el token FCM en Firestore: $e');
    }
  }

  /// Borra el token de este teléfono. Llamar ANTES de cerrar la sesión.
  static Future<void> removeToken() async {
    await _cancelSubscriptions();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token =
          _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(token)
            .delete();
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Error al eliminar el token FCM: $e');
    }
    _currentToken = null;
  }
}
