import 'dart:io';

import 'package:delivery_app/components/widgets/app_widgets.dart';
import 'package:delivery_app/models/claim_model.dart';
import 'package:delivery_app/services/claim_service.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Elige una foto (galería o cámara). Se puede sustituir en pruebas.
/// Devuelve null si el usuario cancela; lanza [ClaimException] si no es válida.
typedef PickImage = Future<XFile?> Function(ImageSource source);

const int _maxPhotoBytes = 5 * 1024 * 1024;

Future<XFile?> _defaultPickImage(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (picked != null && await picked.length() > _maxPhotoBytes) {
    throw const ClaimException('La foto es demasiado pesada (máximo 5 MB).');
  }
  return picked;
}

/// Formulario para reclamar un pedido entregado. Exige una explicación y al
/// menos una foto de evidencia.
class ClaimFormScreen extends StatefulWidget {
  const ClaimFormScreen({
    super.key,
    required this.orderId,
    required this.orderTotal,
    required this.orderStatus,
    required this.userId,
    required this.userName,
    this.contactPhone,
    this.service,
    this.pickImage = _defaultPickImage,
  });

  final String orderId;
  final double orderTotal;
  final String orderStatus;
  final String userId;
  final String userName;
  final String? contactPhone;

  /// Si es null se toma del árbol de providers.
  final ClaimService? service;
  final PickImage pickImage;

  @override
  State<ClaimFormScreen> createState() => _ClaimFormScreenState();
}

class _ClaimFormScreenState extends State<ClaimFormScreen> {
  // El cliente elige entre estos; "cancelacion" queda para uso interno.
  static const _selectableTypes = [
    ClaimType.devolucion,
    ClaimType.queja,
    ClaimType.otro,
  ];

  final _reasonController = TextEditingController();
  final List<String> _photos = [];
  ClaimType _type = ClaimType.devolucion;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _reasonOk =>
      _reasonController.text.trim().length >= ClaimRules.minReasonLength;
  bool get _photosOk => _photos.length >= ClaimRules.minPhotos;
  bool get _canSubmit => _reasonOk && _photosOk && !_submitting;

  String get _orderFolio => widget.orderId
      .substring(0, widget.orderId.length < 6 ? widget.orderId.length : 6)
      .toUpperCase();

  Future<void> _addPhoto(ImageSource source) async {
    if (_photos.length >= ClaimRules.maxPhotos) return;
    try {
      final XFile? picked = await widget.pickImage(source);
      if (picked == null) return; // canceló

      if (!mounted) return;
      setState(() => _photos.add(picked.path));
    } on ClaimException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, kind: SnackKind.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No pudimos abrir la foto. Revisa los permisos de cámara y galería.',
          kind: SnackKind.error,
        );
      }
    }
  }

  void _showPhotoSources() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final service = widget.service ?? context.read<ClaimService>();

    setState(() => _submitting = true);
    try {
      final claimId = await service.createClaim(
        orderId: widget.orderId,
        userId: widget.userId,
        userName: widget.userName,
        type: _type,
        reason: _reasonController.text,
        evidencePaths: List.of(_photos),
        orderTotal: widget.orderTotal,
        orderStatus: widget.orderStatus,
        contactPhone: widget.contactPhone,
      );
      if (!mounted) return;
      final folio = claimId.substring(0, claimId.length < 6 ? claimId.length : 6);
      showAppSnackBar(
        context,
        'Reclamación enviada · Folio #${folio.toUpperCase()}. '
        'Puedes ver su estado en el detalle del pedido.',
        kind: SnackKind.success,
        duration: const Duration(seconds: 5),
      );
      Navigator.pop(context, claimId);
    } on ClaimException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, kind: SnackKind.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No pudimos enviar tu reclamación. Inténtalo de nuevo.',
          kind: SnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canAddMore = _photos.length < ClaimRules.maxPhotos;

    return Scaffold(
      appBar: AppBar(title: const Text('Reclamar pedido')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(
                    'Pedido #$_orderFolio · ${formatMoney(widget.orderTotal)} MXN',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const SectionHeader(title: '¿Qué necesitas?'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _selectableTypes)
                        _TypeChip(
                          label: t.label,
                          selected: _type == t,
                          onTap: _submitting
                              ? null
                              : () => setState(() => _type = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const SectionHeader(title: 'Cuéntanos qué pasó'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reasonController,
                    enabled: !_submitting,
                    maxLines: 5,
                    minLines: 4,
                    maxLength: ClaimRules.maxReasonLength,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ej: El pedido llegó incompleto o dañado…',
                      helperText:
                          'Mínimo ${ClaimRules.minReasonLength} caracteres',
                    ),
                  ),
                  const SizedBox(height: 16),

                  SectionHeader(
                    title: 'Fotos de evidencia (${_photos.length}/${ClaimRules.maxPhotos})',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agrega al menos ${ClaimRules.minPhotos} foto del problema.',
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < _photos.length; i++)
                        _PhotoTile(
                          path: _photos[i],
                          onRemove: _submitting
                              ? null
                              : () => setState(() => _photos.removeAt(i)),
                        ),
                      if (canAddMore)
                        _AddPhotoTile(
                          onTap: _submitting ? null : _showPhotoSources,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Revisaremos tu solicitud y podrás ver su estado en '
                            'el detalle del pedido y con el asistente.',
                            style: TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Botón de envío
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_reasonOk || !_photosOk)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        !_reasonOk && !_photosOk
                            ? 'Explica el motivo y agrega una foto para enviar.'
                            : !_reasonOk
                            ? 'Explica el motivo (mínimo ${ClaimRules.minReasonLength} caracteres).'
                            : 'Agrega al menos una foto para enviar.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enviar reclamación'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderStrong,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

const double _tileSize = 96;

class _PhotoTile extends StatelessWidget {
  final String path;
  final VoidCallback? onRemove;

  const _PhotoTile({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _tileSize,
      height: _tileSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.accentSoft,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    color: AppColors.accent,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: AppColors.ink.withValues(alpha: 0.75),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                    semanticLabel: 'Quitar foto',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: onTap,
        child: const SizedBox(
          width: _tileSize,
          height: _tileSize,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
              SizedBox(height: 6),
              Text(
                'Agregar foto',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
