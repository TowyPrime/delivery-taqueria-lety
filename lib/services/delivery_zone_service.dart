import 'package:cloud_firestore/cloud_firestore.dart';
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

    final partes = [
      '${campo('calle')} ${campo('numero_exterior')}'.trim(),
      campo('colonia'),
      campo('codigo_postal'),
      campo('ciudad'),
      'México',
    ].where((p) => p.isNotEmpty).join(', ');

    try {
      final results = await locationFromAddress(partes);
      if (results.isEmpty) return null;
      return (lat: results.first.latitude, lng: results.first.longitude);
    } catch (_) {
      return null;
    }
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
