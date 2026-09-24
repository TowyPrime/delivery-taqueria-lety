import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Roboto e iconos de Material desde el SDK de Flutter para que los
/// tests de widgets midan texto real (la fuente por defecto de los tests,
/// Ahem, hace cada letra tan ancha como alta y provoca falsos desbordes).
///
/// Si no encuentra el SDK, no hace nada y el test corre con la fuente de prueba.
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return;

  Future<ByteData> bytes(String name) async =>
      ByteData.view(File('$dir/$name').readAsBytesSync().buffer);

  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-light.ttf',
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(bytes(f));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('materialicons-regular.otf'));
  await icons.load();
}
