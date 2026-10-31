import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DeliveryZoneResult {
  final bool inside;
  final double distanceKm;
  final double lat;
  final double lng;

  const DeliveryZoneResult({
    required this.inside,
    required this.distanceKm,
    required this.lat,
    required this.lng,
  });
}

class DeliveryZoneService {
  final FirebaseFirestore _db;

  DeliveryZoneService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  /// Lee centro y radio desde Firestore: config/delivery
  Future<({double lat, double lng, double radiusKm})> _loadConfig() async {
    final snap = await _db.collection('config').doc('delivery').get();
    final data = snap.data();
    if (data == null) {
      throw StateError('Falta el documento config/delivery');
    }
    return (
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      radiusKm: (data['radius_km'] as num).toDouble(),
    );
  }

  /// Convierte el texto de la dirección en coordenadas.
  /// Devuelve null si no se pudo ubicar.
  Future<({double lat, double lng})?> geocodeAddress(
    Map<String, dynamic> direccion,
  ) async {
    String campo(String k) => (direccion[k] ?? '').toString().trim();

    final calle = '${campo('calle')} ${campo('numero_exterior')}'.trim();
    final cp = campo('codigo_postal');
    final colonia = campo('colonia');
    final ciudad = campo('ciudad');

    // De la más precisa a la menos precisa
    final intentos = <List<String>>[
      [calle, colonia, cp, ciudad, 'México'],
      [calle, cp, ciudad, 'México'],
      [cp, ciudad, 'México'],
    ].map((p) => p.where((e) => e.isNotEmpty).join(', ')).toList();

    for (final texto in intentos) {
      try {
        final results = await locationFromAddress(texto);
        if (results.isNotEmpty) {
          debugPrint('Geocodificado con "$texto"');
          return (lat: results.first.latitude, lng: results.first.longitude);
        }
        debugPrint('Geocoding sin resultados con "$texto"');
      } catch (e) {
        debugPrint('Geocoding falló con "$texto": $e');
      }
    }
    return null;
  }

  /// Pide permiso, lee el GPS y lo convierte en dirección.
  /// Lanza [LocationException] con un mensaje listo para mostrar.
  Future<({double lat, double lng, Map<String, String> direccion})>
  currentLocationAddress() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Activa la ubicación de tu teléfono.');
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw const LocationException('Necesitamos el permiso de ubicación.');
    }
    if (permiso == LocationPermission.deniedForever) {
      throw const LocationException(
        'Permiso de ubicación bloqueado. Actívalo en los ajustes de la app.',
      );
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    final marcas = await placemarkFromCoordinates(pos.latitude, pos.longitude);
    final m = marcas.isNotEmpty ? marcas.first : null;

    return (
      lat: pos.latitude,
      lng: pos.longitude,
      direccion: {
        'calle': m?.thoroughfare ?? '',
        'numero_exterior': m?.subThoroughfare ?? '',
        'codigo_postal': m?.postalCode ?? '',
        'colonia': m?.subLocality ?? '',
        'ciudad': m?.locality ?? '',
      },
    );
  }

  /// Revisa si unas coordenadas caen dentro del radio de reparto.
  Future<DeliveryZoneResult> checkCoordinates(double lat, double lng) async {
    final cfg = await _loadConfig();
    final meters = Geolocator.distanceBetween(cfg.lat, cfg.lng, lat, lng);
    final km = meters / 1000;
    return DeliveryZoneResult(
      inside: km <= cfg.radiusKm,
      distanceKm: km,
      lat: lat,
      lng: lng,
    );
  }

  /// Geocodifica la dirección y revisa la zona. Null si no se pudo ubicar.
  Future<DeliveryZoneResult?> checkAddress(
    Map<String, dynamic> direccion,
  ) async {
    final coords = await geocodeAddress(direccion);
    if (coords == null) return null;
    return checkCoordinates(coords.lat, coords.lng);
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
}
