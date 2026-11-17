import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/curso.dart';
import '../../services/auth_service.dart';
import '../../services/estudiante_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cuenta_regresiva.dart';
import '../../widgets/tarjeta.dart';
import 'confirmacion_screen.dart';
import 'historial_estudiante.dart';

/// Pestaña Asistencia del estudiante: escanear el QR o escribir el código.
class AsistenciaEstudianteTab extends StatefulWidget {
  final Usuario usuario;
  final bool activa; // true cuando la pestaña está a la vista

  const AsistenciaEstudianteTab({super.key, required this.usuario, required this.activa});

  @override
  State<AsistenciaEstudianteTab> createState() => _AsistenciaEstudianteTabState();
}

class _AsistenciaEstudianteTabState extends State<AsistenciaEstudianteTab> {
  final _servicio = EstudianteService();
  late final Stream<List<Curso>> _cursos = _servicio.misCursos(widget.usuario.codigo);

  bool _verHistorial = false; // pestaña de arriba: historial o escáner
  bool _procesando = false; // verificando un QR o un código
  bool _enOtraPantalla = false; // la confirmación está abierta encima
  String? _error; // último motivo de rechazo

  @override
  void didUpdateWidget(covariant AsistenciaEstudianteTab anterior) {
    super.didUpdateWidget(anterior);
    // Al entrar a la pestaña siempre se abre en el escáner, que es lo que más se usa
    if (widget.activa && !anterior.activa) _verHistorial = false;
  }

  bool get _camaraEncendida =>
      widget.activa && !_verHistorial && !_procesando && !_enOtraPantalla && _error == null;

  Future<void> _alLeerQr(String contenido) async {
    if (_procesando) return; // la cámara detecta el mismo QR varias veces seguidas
    await _registrar(() => _servicio.marcarConQr(widget.usuario, contenido));
  }

  Future<void> _conCodigo(List<Curso> abiertos) async {
    final elegido = await showDialog<({Curso curso, String pin})>(
      context: context,
      builder: (_) => _DialogoCodigo(cursos: abiertos),
    );
    if (elegido == null) return;
    await _registrar(
        () => _servicio.marcarConCodigo(widget.usuario, elegido.curso, elegido.pin));
  }

  Future<void> _registrar(Future<ResultadoMarca> Function() accion) async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final resultado = await accion();
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _enOtraPantalla = true;
      });
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmacionScreen(resultado: resultado, usuario: widget.usuario),
        ),
      );
      if (mounted) setState(() => _enOtraPantalla = false);
    } on MarcaError catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return SafeArea(
      child: StreamBuilder<List<Curso>>(
        stream: _cursos,
        builder: (context, snapshot) {
          final cursos = snapshot.data ?? const <Curso>[];
          final abiertos = cursos.where((c) => c.sesionAbiertaId != null).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Asistencia', style: texto.headlineLarge),
              const SizedBox(height: 12),

              // ---------- Historial / Escanear ----------
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE9FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    _segmento(texto, 'Sesiones asistidas', Icons.verified_outlined, true),
                    _segmento(texto, 'Escanear QR', Icons.qr_code_scanner, false),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_verHistorial)
                HistorialEstudiante(usuario: widget.usuario)
              else
                ..._escaner(texto, snapshot.hasData, cursos, abiertos),
            ],
          );
        },
      ),
    );
  }

  Widget _segmento(TextTheme texto, String t, IconData icono, bool historial) {
    final activo = _verHistorial == historial;
    final color = activo ? AppColors.primario : AppColors.textoSecundario;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _verHistorial = historial),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texto.labelMedium?.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La parte de escanear: sesiones abiertas, visor y código.
  List<Widget> _escaner(TextTheme texto, bool cargado, List<Curso> cursos, List<Curso> abiertos) {
    return [
      Text('Escanea el código QR que muestra tu docente', style: texto.bodyMedium),
      const SizedBox(height: 12),

      // ---------- Sesiones abiertas en mis cursos ----------
      if (cargado && cursos.isEmpty)
        Tarjeta(
          color: AppColors.campo,
          child: Text(
            'Tu código ${widget.usuario.codigo} todavía no está en la lista de ningún curso. '
            'Pídele a tu docente que te agregue.',
            style: texto.bodyMedium,
          ),
        ),
      for (final c in abiertos) ...[
        _tarjetaSesion(texto, c),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 6),

      // ---------- Visor ----------
      Row(
        children: [
          const Icon(Icons.center_focus_strong, size: 20, color: AppColors.primario),
          const SizedBox(width: 6),
          Expanded(child: Text('Visor de escaneo', style: texto.titleMedium)),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 320,
          child: _contenidoVisor(texto),
        ),
      ),
      const SizedBox(height: 12),

      // ---------- Código ----------
      Center(
        child: TextButton(
          onPressed: _procesando ? null : () => _conCodigo(abiertos),
          child: const Text('¿Problemas con la cámara? Ingresar código'),
        ),
      ),
    ];
  }

  Widget _tarjetaSesion(TextTheme texto, Curso c) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Pildora('EN VIVO · SESIÓN ABIERTA',
                  fondo: Color(0x666CF8BB), color: Color(0xFF00714D), icono: Icons.circle),
              const Spacer(),
              CuentaRegresiva(cursoId: c.id, sesionId: c.sesionAbiertaId!),
            ],
          ),
          const SizedBox(height: 10),
          Text(c.titulo, style: texto.titleMedium),
          Text(
            c.docenteNombre.isEmpty ? c.salon : '${c.salon} · ${c.docenteNombre}',
            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
          ),
        ],
      ),
    );
  }

  /// Lo que se ve dentro del recuadro: la cámara, "verificando" o el motivo del rechazo.
  Widget _contenidoVisor(TextTheme texto) {
    const fondo = Color(0xFF213145);

    if (_procesando) {
      return Container(
        color: fondo,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text('Verificando tu asistencia…',
                style: texto.bodyMedium?.copyWith(color: Colors.white)),
          ],
        ),
      );
    }

    final error = _error;
    if (error != null) {
      return Container(
        color: fondo,
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Color(0xFFFFB3AD)),
            const SizedBox(height: 12),
            Text('No se registró tu asistencia',
                textAlign: TextAlign.center,
                style: texto.titleMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: texto.bodyMedium?.copyWith(color: const Color(0xFFEAF1FF))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _error = null),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primario,
                minimumSize: const Size(180, 44),
                elevation: 0,
              ),
              child: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      );
    }

    if (!_camaraEncendida) {
      return Container(color: fondo);
    }
    return _Visor(alLeer: _alLeerQr);
  }
}

/// La cámara con el marco y la linterna.
/// Crea su propio controlador y lo libera al salir, así la cámara
/// se apaga sola cuando el visor deja de mostrarse.
class _Visor extends StatefulWidget {
  final ValueChanged<String> alLeer;
  const _Visor({required this.alLeer});

  @override
  State<_Visor> createState() => _VisorState();
}

class _VisorState extends State<_Visor> {
  final MobileScannerController _controlador = MobileScannerController();
  bool _linterna = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controlador,
          onDetect: (captura) {
            for (final codigo in captura.barcodes) {
              final valor = codigo.rawValue;
              if (valor != null && valor.isNotEmpty) {
                widget.alLeer(valor);
                return;
              }
            }
          },
        ),
        // Marco de las cuatro esquinas
        Center(
          child: SizedBox(
            width: 208,
            height: 208,
            child: CustomPaint(painter: _MarcoPainter()),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: const Color(0x99213145),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Linterna',
              icon: Icon(_linterna ? Icons.flash_on : Icons.flash_off, color: Colors.white),
              onPressed: () async {
                await _controlador.toggleTorch();
                if (mounted) setState(() => _linterna = !_linterna);
              },
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Text(
            'Apunta al código QR que muestra el docente',
            textAlign: TextAlign.center,
            style: texto.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Dibuja las cuatro esquinas redondeadas del marco de escaneo.
class _MarcoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = AppColors.primarioSuave
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const largo = 30.0;
    const radio = 16.0;
    final w = size.width;
    final h = size.height;

    final trazo = Path()
      // arriba izquierda
      ..moveTo(0, largo)
      ..lineTo(0, radio)
      ..quadraticBezierTo(0, 0, radio, 0)
      ..lineTo(largo, 0)
      // arriba derecha
      ..moveTo(w - largo, 0)
      ..lineTo(w - radio, 0)
      ..quadraticBezierTo(w, 0, w, radio)
      ..lineTo(w, largo)
      // abajo derecha
      ..moveTo(w, h - largo)
      ..lineTo(w, h - radio)
      ..quadraticBezierTo(w, h, w - radio, h)
      ..lineTo(w - largo, h)
      // abajo izquierda
      ..moveTo(largo, h)
      ..lineTo(radio, h)
      ..quadraticBezierTo(0, h, 0, h - radio)
      ..lineTo(0, h - largo);
    canvas.drawPath(trazo, pincel);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ventana para escribir el código de 6 dígitos que dicta el docente.
class _DialogoCodigo extends StatefulWidget {
  final List<Curso> cursos; // cursos del estudiante con sesión abierta
  const _DialogoCodigo({required this.cursos});

  @override
  State<_DialogoCodigo> createState() => _DialogoCodigoState();
}

class _DialogoCodigoState extends State<_DialogoCodigo> {
  final _pinCtrl = TextEditingController();
  late Curso? _curso = widget.cursos.length == 1 ? widget.cursos.first : null;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  bool get _listo => _curso != null && _pinCtrl.text.length == 6;

  void _confirmar() {
    final curso = _curso;
    if (curso == null || _pinCtrl.text.length != 6) return;
    Navigator.pop(context, (curso: curso, pin: _pinCtrl.text));
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    if (widget.cursos.isEmpty) {
      return AlertDialog(
        title: const Text('No hay sesiones abiertas'),
        content: const Text(
            'Ninguno de tus cursos tiene una sesión de asistencia abierta en este momento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Ingresar código'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Escribe el código de 6 dígitos que te dictó tu docente.',
                style: texto.bodyMedium),
            const SizedBox(height: 12),
            if (widget.cursos.length > 1) ...[
              Text('Curso', style: texto.labelMedium),
              const SizedBox(height: 6),
              for (final c in widget.cursos)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _curso?.id == c.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: AppColors.primario,
                  ),
                  title: Text(c.titulo, style: texto.labelLarge?.copyWith(color: AppColors.texto)),
                  onTap: () => setState(() => _curso = c),
                ),
              const SizedBox(height: 8),
            ] else ...[
              Text(widget.cursos.first.titulo, style: texto.labelMedium),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _pinCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: texto.headlineMedium?.copyWith(letterSpacing: 10, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(hintText: '000000'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirmar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: _listo ? _confirmar : null,
          child: const Text('Registrar asistencia'),
        ),
      ],
    );
  }
}
