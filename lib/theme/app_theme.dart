import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores sacados del diseño de Stitch.
class AppColors {
  static const primario = Color(0xFF00288E);           // enlaces y acentos
  static const primarioContenedor = Color(0xFF1E40AF); // botón principal
  static const primarioSuave = Color(0xFFDDE1FF);      // brillo del logo
  static const fondo = Color(0xFFF8F9FF);
  static const campo = Color(0xFFEFF4FF);              // fondo de los campos
  static const contenedor = Color(0xFFE5EEFF);         // fondo del selector de rol
  static const texto = Color(0xFF0B1C30);
  static const textoSecundario = Color(0xFF444653);
  static const contorno = Color(0xFF757684);           // iconos de los campos
  static const contornoSuave = Color(0xFFC4C5D5);      // texto de ejemplo
  static const error = Color(0xFFBA1A1A);
  static const verdeClaro = Color(0xFF6FFBBE);         // escudito del icono
  static const verdeOscuro = Color(0xFF002113);
  static const verde = Color(0xFF006C49);              // reglas cumplidas, "Coinciden"
}

class AppTheme {
  static ThemeData get claro {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primarioContenedor).copyWith(
        primary: AppColors.primario,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primarioContenedor,
        surface: AppColors.fondo,
        onSurface: AppColors.texto,
        onSurfaceVariant: AppColors.textoSecundario,
        outline: AppColors.contorno,
        outlineVariant: AppColors.contornoSuave,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.fondo,
    );

    // Source Sans 3 para el texto normal, Manrope para títulos, etiquetas y botones
    // Se parte del TextTheme de Flutter y solo se le cambia la fuente,
    // así no se usa el TextTheme que trae google_fonts (que choca de tipo).
    final TextTheme textTheme = base.textTheme
        .apply(fontFamily: GoogleFonts.sourceSans3().fontFamily)
        .copyWith(
      headlineLarge: GoogleFonts.manrope(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppColors.texto),
      headlineMedium: GoogleFonts.manrope(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.texto),
      titleMedium: GoogleFonts.manrope(
          fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.texto),
      labelLarge: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.manrope(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.texto),
      labelSmall: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      bodyLarge: GoogleFonts.sourceSans3(fontSize: 17, color: AppColors.texto),
      bodyMedium: GoogleFonts.sourceSans3(fontSize: 15, color: AppColors.textoSecundario),
    );

    OutlineInputBorder borde([Color? color, double ancho = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: ancho),
        );

    return base.copyWith(
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.campo,
        hintStyle: GoogleFonts.sourceSans3(fontSize: 17, color: AppColors.contornoSuave),
        prefixIconColor: AppColors.contorno,
        suffixIconColor: AppColors.contorno,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: borde(),
        enabledBorder: borde(),
        focusedBorder: borde(AppColors.primarioContenedor),
        errorBorder: borde(AppColors.error, 1),
        focusedErrorBorder: borde(AppColors.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primarioContenedor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          elevation: 3,
          shadowColor: AppColors.primarioContenedor.withValues(alpha: 0.4),
          textStyle: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primario,
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
