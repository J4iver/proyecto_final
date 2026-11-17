import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/curso.dart';
import '../../models/sesion.dart';
import '../../services/curso_service.dart';
import '../../services/sesion_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/tarjeta.dart';
import 'lista_asistencia_screen.dart';

/// Llamado a lista con tarjetas:
/// deslizar hacia arriba = presente, hacia la izquierda = ausente.
class ModoCardsScreen extends StatefulWidget {
  final Curso curso;
  final Sesion sesion;

  const ModoCardsScreen({super.key, required this.curso, required this.sesion});

  @override
  State<ModoCardsScreen> createState() => _ModoCardsScreenState();
}

class _ModoCardsScreenState extends State<ModoCardsScreen> {
  static const _umbral = 90.0; // cuánto hay que arrastrar para que cuente

  final _servicio = SesionService();
  StreamSubscription<List<Asistencia>>? _subAsistencias;
  StreamSubscription<Sesion?>? _subSesion;

  List<EstudianteCurso>? _cola; // pendientes al entrar, en orden alfabético
  Map<String, Asistencia> _marcas = {};
  int _total = 0;
  int _i = 0; // posición en la cola
  final List<int> _historial = []; // posiciones marcadas aquí, para deshacer
  Offset _arrastre = Offset.zero;

  String get _cursoId => widget.curso.id;
  String get _sesionId => widget.sesion.id;

  @override
  void initState() {
    super.initState();
    _cargar();
    _subAsistencias = _servicio.asistencias(_cursoId, _sesionId).listen((lista) {
      if (!mounted) return;
      setState(() {
        _marcas = {for (final a in lista) a.codigo: a};
        _saltarYaRegistrados();
      });
    });
    // Si la sesión se cierra (por tiempo o desde otra pantalla), se sale de aquí
    _subSesion = _servicio.sesion(_cursoId, _sesionId).listen((s) {
      if (!mounted || s == null || s.abierta) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('La sesión se cerró.')));
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _subAsistencias?.cancel();
    _subSesion?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final estudiantes = await CursoService().leerEstudiantes(_cursoId);
      final yaMarcados = await _servicio.asistencias(_cursoId, _sesionId).first;
      final codigos = yaMarcados.map((a) => a.codigo).toSet();
      if (!mounted) return;
      setState(() {
        _total = estudiantes.length;
        _cola = estudiantes.where((e) => !codigos.contains(e.codigo)).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cola = []);
    }
  }

  /// Si el que sigue ya se registró por QR o código mientras tanto, se pasa al siguiente.
  void _saltarYaRegistrados() {
    final cola = _cola;
    if (cola == null) return;
    while (_i < cola.length) {
      final marca = _marcas[cola[_i].codigo];
      if (marca == null || marca.metodo == 'cards') break;
      _i++;
    }
  }

  Future<void> _marcar(bool presente) async {
    final cola = _cola;
    if (cola == null || _i >= cola.length) return;
    final estudiante = cola[_i];
    setState(() {
      _historial.add(_i);
      _i++;
      _arrastre = Offset.zero;
      _saltarYaRegistrados();
    });
    try {
      await _servicio.marcar(_cursoId, _sesionId, estudiante, presente: presente, metodo: 'cards');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar a ${estudiante.nombre}.')));
    }
  }

  Future<void> _deshacer() async {
    final cola = _cola;
    if (cola == null || _historial.isEmpty) return;
    final posicion = _historial.removeLast();
    setState(() {
      _i = posicion;
      _arrastre = Offset.zero;
    });
    try {
      await _servicio.desmarcar(_cursoId, _sesionId, cola[posicion].codigo);
    } catch (_) {
      // Si falla, la marca anterior se conserva y se puede corregir desde la lista
    }
  }

  void _soltar() {
    final haciaArriba = _arrastre.dy < -_umbral && _arrastre.dy.abs() > _arrastre.dx.abs();
    final haciaIzquierda = _arrastre.dx < -_umbral && _arrastre.dx.abs() >= _arrastre.dy.abs();
    if (haciaArriba) {
      _marcar(true);
    } else if (haciaIzquierda) {
      _marcar(false);
    } else {
      setState(() => _arrastre = Offset.zero);
    }
  }

  void _verLista() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ListaAsistenciaScreen(curso: widget.curso, sesion: widget.sesion),
      ),
    );
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final cola = _cola;

    final presentes = _marcas.values.where((a) => a.presente).length;
    final ausentes = _marcas.values.where((a) => !a.presente).length;
    final pendientes = (_total - presentes - ausentes).clamp(0, _total).toInt();
    final double avance = _total == 0 ? 0.0 : (presentes + ausentes) / _total;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Column(
          children: [
            Text(widget.curso.titulo, style: texto.titleMedium),
            Text(widget.sesion.tituloVisible,
                style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: cola == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    // ---------- Progreso ----------
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: avance.clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        backgroundColor: AppColors.contenedor,
                        color: AppColors.primario,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.record_voice_over_outlined,
                            size: 20, color: AppColors.primario),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Llamado a lista', style: texto.titleMedium)),
                        Pildora('${presentes + ausentes} de $_total',
                            fondo: AppColors.primarioSuave, color: AppColors.primario),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _contador(texto, '$presentes presentes', AppColors.verde)),
                        const SizedBox(width: 6),
                        Expanded(child: _contador(texto, '$ausentes ausentes', AppColors.error)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: _contador(texto, '$pendientes pendientes', AppColors.contorno)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_i >= cola.length)
                      Expanded(child: _terminado(texto, presentes, ausentes))
                    else ...[
                      // ---------- Pistas del gesto ----------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Pildora('Izquierda · Ausente',
                              fondo: const Color(0x66FFDAD6),
                              color: const Color(0xFF93000A),
                              icono: Icons.arrow_back),
                          Pildora('Arriba · Presente',
                              fondo: const Color(0x666CF8BB),
                              color: const Color(0xFF00714D),
                              icono: Icons.arrow_upward),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ---------- Tarjetas ----------
                      Expanded(child: _pila(texto, cola)),
                      const SizedBox(height: 12),

                      // ---------- Botones ----------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _botonRedondo(texto, 'Ausente', Icons.close, AppColors.error,
                              Colors.white, 56, () => _marcar(false)),
                          const SizedBox(width: 24),
                          _botonRedondo(texto, 'Deshacer', Icons.undo, AppColors.textoSecundario,
                              AppColors.contenedor, 48, _historial.isEmpty ? null : _deshacer),
                          const SizedBox(width: 24),
                          _botonRedondo(texto, 'Presente', Icons.check, Colors.white,
                              AppColors.verde, 64, () => _marcar(true)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _verLista,
                      icon: const Icon(Icons.format_list_bulleted, size: 18),
                      label: const Text('Cambiar a vista de lista'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _contador(TextTheme texto, String t, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(t,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: texto.labelSmall?.copyWith(color: color)),
    );
  }

  /// La tarjeta de arriba (que se arrastra) y la siguiente asomada debajo.
  Widget _pila(TextTheme texto, List<EstudianteCurso> cola) {
    final actual = cola[_i];
    final haySiguiente = _i + 1 < cola.length;

    // Qué tan cerca está de contar como presente o ausente (de 0 a 1)
    final fuerzaPresente = (-_arrastre.dy / _umbral).clamp(0.0, 1.0).toDouble();
    final fuerzaAusente = (-_arrastre.dx / _umbral).clamp(0.0, 1.0).toDouble();
    final vaArriba = _arrastre.dy.abs() > _arrastre.dx.abs();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (haySiguiente)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.contenedor,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _arrastre += d.delta),
            onPanEnd: (_) => _soltar(),
            onPanCancel: () => setState(() => _arrastre = Offset.zero),
            child: Transform.translate(
              offset: _arrastre,
              child: Transform.rotate(
                angle: _arrastre.dx / 900,
                child: _tarjeta(
                  texto,
                  actual,
                  presente: vaArriba ? fuerzaPresente : 0.0,
                  ausente: vaArriba ? 0.0 : fuerzaAusente,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(TextTheme texto, EstudianteCurso e,
      {required double presente, required double ausente}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: AppColors.primarioSuave,
                  child: Text(
                    iniciales(e.nombre),
                    style: texto.headlineLarge?.copyWith(fontSize: 40, color: AppColors.primario),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(e.nombre, textAlign: TextAlign.center, style: texto.headlineMedium),
              const SizedBox(height: 6),
              Text(
                e.programa.isEmpty ? 'Código ${e.codigo}' : '${e.programa} · ${e.codigo}',
                textAlign: TextAlign.center,
                style: texto.bodyMedium,
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: presente,
              child: const Pildora('PRESENTE',
                  fondo: AppColors.verde, color: Colors.white, icono: Icons.check_circle),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Opacity(
              opacity: ausente,
              child: const Pildora('AUSENTE',
                  fondo: AppColors.error, color: Colors.white, icono: Icons.cancel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonRedondo(TextTheme texto, String etiqueta, IconData icono, Color color, Color fondo,
      double tamano, VoidCallback? alTocar) {
    final apagado = alTocar == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: fondo,
          shape: const CircleBorder(),
          elevation: apagado ? 0 : 4,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: alTocar,
            child: SizedBox(
              width: tamano,
              height: tamano,
              child: Icon(icono,
                  size: tamano * 0.5, color: apagado ? AppColors.contornoSuave : color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(etiqueta,
            style: texto.labelSmall
                ?.copyWith(color: apagado ? AppColors.contornoSuave : AppColors.textoSecundario)),
      ],
    );
  }

  Widget _terminado(TextTheme texto, int presentes, int ausentes) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.task_alt, size: 64, color: AppColors.verde),
          const SizedBox(height: 12),
          Text('Ya llamaste a todos', style: texto.headlineMedium),
          const SizedBox(height: 4),
          Text('$presentes presentes y $ausentes ausentes.',
              textAlign: TextAlign.center, style: texto.bodyMedium),
          const SizedBox(height: 20),
          if (_historial.isNotEmpty)
            TextButton.icon(
              onPressed: _deshacer,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Deshacer la última'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver a la sesión'),
          ),
        ],
      ),
    );
  }
}
