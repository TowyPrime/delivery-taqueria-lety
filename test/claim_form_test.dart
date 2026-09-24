import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/models/claim_model.dart';
import 'package:delivery_app/screens/claim_form_screen.dart';
import 'package:delivery_app/services/claim_service.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers/test_fonts.dart';

const _reason = 'El pedido llegó incompleto y frío.';

class _FakeClaimService extends ClaimService {
  Map<String, Object?>? last;
  Object? error;

  @override
  Future<String> createClaim({
    required String orderId,
    required String userId,
    required String userName,
    required ClaimType type,
    required String reason,
    required List<String> evidencePaths,
    required double orderTotal,
    required String orderStatus,
    String? contactPhone,
  }) async {
    last = {
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'type': type,
      'reason': reason,
      'paths': evidencePaths,
      'orderTotal': orderTotal,
      'orderStatus': orderStatus,
      'phone': contactPhone,
    };
    if (error != null) throw error!;
    return 'claim123456';
  }
}

void main() {
  setUpAll(loadTestFonts);

  late _FakeClaimService service;
  var photoCounter = 0;

  Future<XFile?> fakePick(ImageSource source) async =>
      XFile('/fake/foto_${++photoCounter}.jpg');

  Future<void> pumpForm(WidgetTester tester, {PickImage? pick}) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    service = _FakeClaimService();
    photoCounter = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClaimFormScreen(
                      orderId: 'abc123xyz',
                      orderTotal: 120,
                      orderStatus: 'entregado',
                      userId: 'u1',
                      userName: 'Prueba',
                      contactPhone: '5512345678',
                      service: service,
                      pickImage: pick ?? fakePick,
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  FilledButton submitButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Enviar reclamación'),
  );

  Future<void> addPhoto(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Agregar foto'));
    await tester.tap(find.text('Agregar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
  }

  Future<void> writeReason(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  testWidgets('empieza con el envío deshabilitado y muestra el folio', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.textContaining('Pedido #ABC123'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
    expect(
      find.text('Explica el motivo y agrega una foto para enviar.'),
      findsOneWidget,
    );
  });

  testWidgets('con motivo pero sin foto sigue deshabilitado', (tester) async {
    await pumpForm(tester);

    await writeReason(tester, _reason);

    expect(submitButton(tester).onPressed, isNull);
    expect(find.text('Agrega al menos una foto para enviar.'), findsOneWidget);
  });

  testWidgets('con foto pero motivo corto sigue deshabilitado', (tester) async {
    await pumpForm(tester);

    await addPhoto(tester);
    await writeReason(tester, 'corto');

    expect(submitButton(tester).onPressed, isNull);
    expect(find.textContaining('mínimo 10 caracteres'), findsWidgets);
  });

  testWidgets('motivo + una foto habilita el envío', (tester) async {
    await pumpForm(tester);

    await writeReason(tester, _reason);
    await addPhoto(tester);

    expect(find.text('Fotos de evidencia (1/3)'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('máximo 3 fotos: desaparece "Agregar foto"', (tester) async {
    await pumpForm(tester);

    await addPhoto(tester);
    await addPhoto(tester);
    await addPhoto(tester);

    expect(find.text('Fotos de evidencia (3/3)'), findsOneWidget);
    expect(find.text('Agregar foto'), findsNothing);
  });

  testWidgets('quitar la única foto vuelve a deshabilitar el envío', (
    tester,
  ) async {
    await pumpForm(tester);
    await writeReason(tester, _reason);
    await addPhoto(tester);
    expect(submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(find.text('Fotos de evidencia (0/3)'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('cancelar el selector de fotos no agrega nada', (tester) async {
    await pumpForm(tester, pick: (_) async => null);

    await addPhoto(tester);

    expect(find.text('Fotos de evidencia (0/3)'), findsOneWidget);
  });

  testWidgets('enviar: manda los datos al servicio, avisa y cierra', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.text('Queja'));
    await tester.pump();
    await writeReason(tester, _reason);
    await addPhoto(tester);

    await tester.ensureVisible(find.text('Enviar reclamación'));
    await tester.tap(find.text('Enviar reclamación'));
    await tester.pumpAndSettle();

    expect(service.last, {
      'orderId': 'abc123xyz',
      'userId': 'u1',
      'userName': 'Prueba',
      'type': ClaimType.queja,
      'reason': _reason,
      'paths': ['/fake/foto_1.jpg'],
      'orderTotal': 120.0,
      'orderStatus': 'entregado',
      'phone': '5512345678',
    });
    // Volvió a la pantalla anterior y mostró el folio.
    expect(find.byType(ClaimFormScreen), findsNothing);
    expect(find.textContaining('Folio #CLAIM1'), findsOneWidget);
  });

  testWidgets('si el servicio rechaza, muestra el mensaje y permite reintentar', (
    tester,
  ) async {
    await pumpForm(tester);
    service.error = const ClaimException('Este pedido ya tiene una reclamación.');
    await writeReason(tester, _reason);
    await addPhoto(tester);

    await tester.ensureVisible(find.text('Enviar reclamación'));
    await tester.tap(find.text('Enviar reclamación'));
    await tester.pumpAndSettle();

    expect(find.text('Este pedido ya tiene una reclamación.'), findsOneWidget);
    expect(find.byType(ClaimFormScreen), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  group('ClaimSummaryCard', () {
    Future<void> pumpCard(WidgetTester tester, ClaimModel claim) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: ClaimSummaryCard(claim: claim)),
        ),
      );
    }

    testWidgets('abierta: folio, estado y motivo, sin respuesta', (tester) async {
      await pumpCard(
        tester,
        ClaimModel(
          id: 'abc123xyz',
          orderId: 'o1',
          userId: 'u1',
          type: ClaimType.devolucion,
          reason: 'Llegó incompleto',
          status: ClaimStatus.enRevision,
          createdAt: DateTime(2026, 9, 12),
        ),
      );

      expect(find.text('Reclamación #ABC123'), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Devolución · 12/09/2026'), findsOneWidget);
      expect(find.text('Llegó incompleto'), findsOneWidget);
      expect(find.text('Respuesta de Taquería Lety'), findsNothing);
    });

    testWidgets('resuelta: muestra la respuesta y el reembolso', (tester) async {
      await pumpCard(
        tester,
        ClaimModel(
          id: 'abc123xyz',
          orderId: 'o1',
          userId: 'u1',
          type: ClaimType.devolucion,
          reason: 'Llegó incompleto',
          status: ClaimStatus.resuelta,
          createdAt: DateTime(2026, 9, 12),
          resolution: 'Reembolso aprobado',
          refundAmount: 120,
        ),
      );

      expect(find.text('Resuelta'), findsOneWidget);
      expect(find.text('Respuesta de Taquería Lety'), findsOneWidget);
      expect(find.text('Reembolso aprobado'), findsOneWidget);
      expect(find.text('Reembolso: \$120.00 MXN'), findsOneWidget);
    });
  });
}
