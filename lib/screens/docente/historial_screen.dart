import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../models/sesion.dart';
import '../../services/sesion_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/tarjeta.dart';
import 'lista_asistencia_screen.dart';
import 'sesion_screen.dart';

/// Fila de una sesión: icono, título, fecha y cuántos asistieron.
/// La usan el Historial y el Detalle del curso.
class FilaSesion extends StatelessWidget {
  final Curso curso;
  final Sesion sesion;
  const FilaSesion({super.key, required this.curso, required this.sesion});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final porCards = sesion.modo == 'cards';
    final porcentaje = sesion.total == 0 ? 0 : (sesion.presentes * 100 / sesion.total).round();

    return InkWell(
      onTap: () {
        // Una sesión abierta se gestiona; una cerrada solo se consulta
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => sesion.abierta
                ? SesionScreen(curso: curso, sesionId: sesion.id)
                : ListaAsistenciaScreen(curso: curso, sesion: sesion),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: porCards ? const Color(0x666CF8BB) : AppColors.primarioSuave,
              child: Icon(porCards ? Icons.style_outlined : Icons.qr_code_2,
                  size: 18, color: porCards ? const Color(0xFF00714D) : AppColors.primario),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sesion.tituloVisible,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.labelLarge?.copyWith(color: AppColors.texto)),
                  Text(formatoFecha(sesion.inicio),
                      style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                ],
              ),
            ),
            if (sesion.abierta)
              const Pildora('EN CURSO', fondo: Color(0x666CF8BB), color: Color(0xFF00714D))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${sesion.presentes}/${sesion.total}',
                      style: texto.labelLarge?.copyWith(color: AppColors.verde)),
                  Text('$porcentaje% asistió',
                      style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
                ],
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.contornoSuave),
          ],
        ),
      ),
    );
  }
}

/// Historial de asistencia: todas las sesiones de un curso.
class HistorialScreen extends StatefulWidget {
  final Curso curso;
  const HistorialScreen({super.key, required this.curso});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late final Stream<List<Sesion>> _sesiones = SesionService().sesionesDelCurso(widget.curso.id);

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Historial de asistencia', style: texto.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Sesion>>(
          stream: _sesiones,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final sesiones = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(widget.curso.titulo, style: texto.headlineMedium),
                Text('${sesiones.length} ${sesiones.length == 1 ? 'sesión' : 'sesiones'}',
                    style: texto.bodyMedium),
                const SizedBox(height: 12),
                if (sesiones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text('Aún no se ha tomado asistencia en este curso.',
                        textAlign: TextAlign.center, style: texto.bodyMedium),
                  )
                else
                  Tarjeta(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < sesiones.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.campo),
                          FilaSesion(curso: widget.curso, sesion: sesiones[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
