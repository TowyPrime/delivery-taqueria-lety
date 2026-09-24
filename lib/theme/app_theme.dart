import 'package:flutter/material.dart';

/// Paleta tomada del logo de Taquería Lety: rojo chile, ámbar, crema,
/// verde limón y café oscuro para el texto.
class AppColors {
  AppColors._();

  static const primary = Color(0xFFC8391A);
  static const primaryDark = Color(0xFF8C2410);
  static const primarySoft = Color(0xFFFBE7DF);

  static const accent = Color(0xFFF2A33A);
  static const accentSoft = Color(0xFFFFF0D6);
  static const warning = Color(0xFF9A5B00);

  static const success = Color(0xFF4B7A1F);
  static const successSoft = Color(0xFFE9F2DC);

  static const info = Color(0xFF2A72A5);
  static const infoSoft = Color(0xFFE3F1FA);

  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFBE4E1);

  static const background = Color(0xFFFBF5EA);
  static const surface = Colors.white;

  static const ink = Color(0xFF3A2018);
  static const inkSoft = Color(0xFF7A6259);

  static const border = Color(0xFFEADFCB);
  static const borderStrong = Color(0xFFD9CBB2);
}

/// Radios y espaciados compartidos para mantener un ritmo visual consistente.
class AppSpacing {
  AppSpacing._();

  static const double page = 16;
  static const double radiusSmall = 12;
  static const double radius = 16;
  static const double radiusLarge = 24;

  /// Espacio al final de listas para que el botón flotante del chat no
  /// tape el último elemento (56 del botón + márgenes).
  static const double fabClearance = 88;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.accent,
          onSecondary: AppColors.ink,
          secondaryContainer: AppColors.accentSoft,
          onSecondaryContainer: AppColors.ink,
          tertiary: AppColors.success,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.inkSoft,
          outline: AppColors.borderStrong,
          outlineVariant: AppColors.border,
          error: AppColors.danger,
        );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    // Los estilos heredan la tipografía del tema (en vez de un TextStyle "suelto").
    TextStyle buttonText(double size) => textTheme.labelLarge!.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
    );

    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge!.copyWith(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
        actionsIconTheme: const IconThemeData(color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: AppColors.inkSoft),
        hintStyle: TextStyle(color: AppColors.inkSoft.withValues(alpha: 0.7)),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? AppColors.primary
              : AppColors.inkSoft,
        ),
        suffixIconColor: AppColors.inkSoft,
        border: inputBorder(AppColors.borderStrong),
        enabledBorder: inputBorder(AppColors.borderStrong),
        focusedBorder: inputBorder(AppColors.primary, 2),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.inkSoft,
          minimumSize: const Size(64, 50),
          elevation: 0,
          shape: roundedShape,
          textStyle: buttonText(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.inkSoft,
          minimumSize: const Size(64, 50),
          shape: roundedShape,
          textStyle: buttonText(16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: roundedShape,
          textStyle: buttonText(15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: buttonText(15),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: AppColors.ink.withValues(alpha: 0.25),
        height: 68,
        indicatorColor: AppColors.primarySoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.inkSoft,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.inkSoft,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge - 4),
        ),
        titleTextStyle: textTheme.titleLarge!.copyWith(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: AppColors.inkSoft,
          fontSize: 15,
          height: 1.35,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLarge),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.primary),
    );
  }
}

enum SnackKind { success, error, info }

/// SnackBar unificado: mismo estilo, icono y colores en toda la app.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackKind kind = SnackKind.info,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final (Color color, IconData icon) = switch (kind) {
    SnackKind.success => (AppColors.success, Icons.check_circle_rounded),
    SnackKind.error => (AppColors.danger, Icons.error_rounded),
    SnackKind.info => (AppColors.ink, Icons.info_rounded),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: duration,
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction ?? () {},
              ),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Apariencia de cada estado de pedido. Acepta tanto "preparando" (usado por
/// las notificaciones) como "en preparación" (usado en el historial).
class OrderStatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  const OrderStatusStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  static OrderStatusStyle of(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pendiente':
        return const OrderStatusStyle(
          label: 'Pendiente',
          icon: Icons.schedule_rounded,
          color: AppColors.warning,
          background: AppColors.accentSoft,
        );
      case 'preparando':
      case 'en preparación':
      case 'en preparacion':
        return const OrderStatusStyle(
          label: 'En cocina',
          icon: Icons.soup_kitchen_rounded,
          color: AppColors.primary,
          background: AppColors.primarySoft,
        );
      case 'en camino':
        return const OrderStatusStyle(
          label: 'En camino',
          icon: Icons.delivery_dining_rounded,
          color: AppColors.info,
          background: AppColors.infoSoft,
        );
      case 'entregado':
        return const OrderStatusStyle(
          label: 'Entregado',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          background: AppColors.successSoft,
        );
      case 'cancelado':
        return const OrderStatusStyle(
          label: 'Cancelado',
          icon: Icons.cancel_rounded,
          color: AppColors.danger,
          background: AppColors.dangerSoft,
        );
      default:
        return OrderStatusStyle(
          label: status.isEmpty
              ? 'Desconocido'
              : status[0].toUpperCase() + status.substring(1),
          icon: Icons.help_outline_rounded,
          color: AppColors.inkSoft,
          background: AppColors.border,
        );
    }
  }
}
