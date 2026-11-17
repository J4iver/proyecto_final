import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Selector Docente / Estudiante con la "píldora" blanca que se desliza.
class SelectorRol extends StatelessWidget {
  final Rol valor;
  final ValueChanged<Rol> alCambiar;

  const SelectorRol({super.key, required this.valor, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.contenedor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Píldora blanca que se mueve hacia el rol seleccionado
          AnimatedAlign(
            alignment: valor == Rol.docente ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _opcion(context, Rol.docente, Icons.school_outlined),
              _opcion(context, Rol.estudiante, Icons.backpack_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _opcion(BuildContext context, Rol rol, IconData icono) {
    final activo = rol == valor;
    final color = activo ? AppColors.primario : AppColors.textoSecundario;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => alCambiar(rol),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(width: 6),
            Text(rol.etiqueta,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
