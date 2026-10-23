import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class PostalCodeInfo {
  final String ciudad;
  final String municipio;
  final String estado;
  final List<String> colonias;

  const PostalCodeInfo({
    required this.ciudad,
    required this.municipio,
    required this.estado,
    required this.colonias,
  });
}

class PostalCodeService {
  static const _assetPath = 'assets/data/codigos_postales.json';

  // Se lee del asset una sola vez y se reutiliza en toda la app
  static Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _load() async {
    _cache ??=
        jsonDecode(await rootBundle.loadString(_assetPath))
            as Map<String, dynamic>;
    return _cache!;
  }

  Future<PostalCodeInfo?> lookup(String cp) async {
    final data = await _load();
    final item = data[cp.trim()] as Map<String, dynamic>?;
    if (item == null) return null;
    return PostalCodeInfo(
      ciudad: item['ciudad'] as String,
      municipio: item['municipio'] as String,
      estado: item['estado'] as String,
      colonias: List<String>.from(item['colonias'] as List),
    );
  }
}
