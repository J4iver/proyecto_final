import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Perfil básico: datos de la cuenta y cerrar sesión.
class PerfilScreen extends StatelessWidget {
  final Usuario usuario;
  const PerfilScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primarioContenedor,
              child: Text(iniciales(usuario.nombre),
                  style: texto.headlineMedium?.copyWith(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            Text(usuario.nombre, textAlign: TextAlign.center, style: texto.headlineMedium),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.contenedor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(usuario.rol.etiqueta,
                  style: texto.labelMedium?.copyWith(color: AppColors.primario)),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _dato(texto, Icons.mail_outline, 'Correo institucional', usuario.email),
                  const Divider(height: 1, indent: 56, color: AppColors.contenedor),
                  _dato(texto, Icons.pin_outlined, 'Código', usuario.codigo),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: AuthService().cerrarSesion,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(TextTheme texto, IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, size: 22, color: AppColors.primarioContenedor),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                Text(valor.isEmpty ? 'Sin registrar' : valor,
                    style: texto.bodyLarge?.copyWith(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
