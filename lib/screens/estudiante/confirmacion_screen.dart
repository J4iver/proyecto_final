import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/estudiante_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/asistencia_ui.dart';
import '../../widgets/tarjeta.dart';
import 'con_datos.dart';

/// Confirmación de que la asistencia quedó registrada.
class ConfirmacionScreen extends StatelessWidget {
  final ResultadoMarca resultado;
  final Usuario usuario;
  const ConfirmacionScreen({super.key, required this.resultado, required this.usuario});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final curso = resultado.curso;
    final distancia = resultado.distancia;
    final porQr = resultado.metodo == 'qr';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          children: [
            Tarjeta(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: Column(
                children: [
                  // El check aparece creciendo: es la única animación de la pantalla
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, escala, child) =>
                        Transform.scale(scale: escala, child: child),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6CF8BB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, size: 40, color: Color(0xFF00714D)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('¡Asistencia registrada!',
                      textAlign: TextAlign.center, style: texto.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    porQr
                        ? 'Tu asistencia quedó verificada con el código QR del docente.'
                        : 'Tu asistencia quedó registrada con el código del docente.',
                    textAlign: TextAlign.center,
                    style: texto.bodyMedium,
                  ),
                  const SizedBox(height: 20),

                  // ---------- Datos del registro ----------
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.campo,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _dato(texto, Icons.school_outlined, 'Curso', curso.titulo, destacado: true),
                        const Divider(height: 20, color: AppColors.contenedor),
                        _dato(texto, Icons.event_note_outlined, 'Sesión',
                            resultado.sesion.tituloVisible),
                        const SizedBox(height: 10),
                        _dato(texto, Icons.schedule, 'Registro', formatoFecha(resultado.hora)),
                        const SizedBox(height: 10),
                        _dato(
                          texto,
                          Icons.meeting_room_outlined,
                          'Salón',
                          curso.docenteNombre.isEmpty
                              ? curso.salon
                              : '${curso.salon} · ${curso.docenteNombre}',
                        ),
                        const Divider(height: 20, color: AppColors.contenedor),
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined,
                                size: 18, color: AppColors.verde),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Método',
                                  style: texto.labelSmall
                                      ?.copyWith(color: AppColors.textoSecundario)),
                            ),
                            Pildora(porQr ? 'QR dinámico' : 'Código del docente',
                                fondo: const Color(0xFF6CF8BB), color: const Color(0xFF00714D)),
                          ],
                        ),
                        if (distancia != null) ...[
                          const SizedBox(height: 10),
                          _dato(texto, Icons.pin_drop_outlined, 'Ubicación',
                              'Verificada, a ${distancia.round()} m del docente',
                              colorValor: AppColors.verde),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Progreso en el curso ----------
            ConDatos(
              usuario: usuario,
              builder: (context, datos) {
                final r = datos.resumen(curso);
                if (r.total == 0) return const SizedBox.shrink();
                return Tarjeta(
                  child: Row(
                    children: [
                      AnilloAsistencia(
                          valor: r.porcentaje,
                          color: r.conAlerta ? colorNivel(r.nivel) : AppColors.verde),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tu progreso en el curso',
                                style: texto.labelLarge?.copyWith(color: AppColors.texto)),
                            const SizedBox(height: 4),
                            PildoraNivel(r.nivel),
                            const SizedBox(height: 6),
                            Text('Has asistido a ${r.asistidas} de ${r.total} sesiones.',
                                style: texto.bodySmall
                                    ?.copyWith(color: AppColors.textoSecundario)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.done_all, size: 20),
              label: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(TextTheme texto, IconData icono, String etiqueta, String valor,
      {bool destacado = false, Color? colorValor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: AppColors.primario),
        const SizedBox(width: 8),
        Text(etiqueta, style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: (destacado ? texto.titleMedium : texto.labelMedium)
                ?.copyWith(color: colorValor ?? AppColors.texto),
          ),
        ),
      ],
    );
  }
}
