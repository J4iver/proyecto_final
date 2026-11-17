import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pestaña que todavía no se ha construido.
class Pendiente extends StatelessWidget {
  final IconData icono;
  final String titulo;
  const Pendiente({super.key, required this.icono, required this.titulo});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48, color: AppColors.contornoSuave),
          const SizedBox(height: 12),
          Text(titulo, style: texto.titleMedium),
          const SizedBox(height: 4),
          Text('Esta pantalla se construye en el siguiente paso.', style: texto.bodyMedium),
        ],
      ),
    );
  }
}
