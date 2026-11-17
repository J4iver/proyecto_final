import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/curso.dart';
import '../../models/sesion.dart';
import '../../services/sesion_service.dart';
import '../../services/ubicacion_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/tarjeta.dart';
import 'lista_asistencia_screen.dart';
import 'modo_cards_screen.dart';

/// Abre (o retoma) la sesión de asistencia de un curso y entra a su pantalla.
/// Si el curso valida ubicación, primero toma el GPS del docente.
Future<void> abrirSesion(
  BuildContext context,
  Curso curso, {
  String titulo = '',
  bool cards = false,
}) async {
  final mensajes = ScaffoldMessenger.of(context);
  final navegador = Navigator.of(context);

  double? lat;
  double? lng;
  final esNueva = curso.sesionAbiertaId == null;
  if (esNueva && curso.exigirUbicacion) {
    try {
      final posicion = await UbicacionService.actual();
      lat = posicion.latitude;
      lng = posicion.longitude;
    } on UbicacionError catch (e) {
      if (!context.mounted) return;
      final seguir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se pudo obtener tu ubicación'),
          content: Text('${e.mensaje}\n\n¿Quieres iniciar esta sesión sin validar el GPS de los estudiantes?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Iniciar sin GPS')),
          ],
        ),
      );
      if (seguir != true) return;
    }
  }

  try {
    final sesionId = await SesionService().iniciar(
      curso,
      titulo: titulo,
      modo: cards ? 'cards' : 'qr',
      lat: lat,
      lng: lng,
    );
    await navegador.push(MaterialPageRoute(
      builder: (_) => SesionScreen(curso: curso, sesionId: sesionId, abrirCards: cards),
    ));
  } catch (_) {
    mensajes.showSnackBar(
      const SnackBar(content: Text('No se pudo iniciar la sesión. Revisa las reglas de Firestore.')),
    );
  }
}

/// Toma de asistencia: QR que rota, código de un solo uso y progreso en vivo.
class SesionScreen extends StatefulWidget {
  final Curso curso;
  final String sesionId;
  final bool abrirCards;

  const SesionScreen({
    super.key,
    required this.curso,
    required this.sesionId,
    this.abrirCards = false,
  });

  @override
  State<SesionScreen> createState() => _SesionScreenState();
}

class _SesionScreenState extends State<SesionScreen> {
  final _servicio = SesionService();
  StreamSubscription<Sesion?>? _subSesion;
  StreamSubscription<List<Asistencia>>? _subAsistencias;
  StreamSubscription<bool>? _subCodigo;
  Timer? _reloj;

  Sesion? _sesion;
  List<Asistencia> _asistencias = [];
  bool _cargando = true;

  DateTime _ultimaRotacion = DateTime.now();
  bool _rotando = false;
  bool _cerrando = false;

  String? _codigo;
  DateTime? _codigoExpira;
  bool _codigoUsado = false;
  bool _generando = false;

  String get _cursoId => widget.curso.id;

  @override
  void initState() {
    super.initState();
    _subSesion = _servicio.sesion(_cursoId, widget.sesionId).listen((s) {
      if (!mounted) return;
      setState(() {
        _sesion = s;
        _cargando = false;
      });
    });
    _subAsistencias = _servicio.asistencias(_cursoId, widget.sesionId).listen((lista) {
      if (!mounted) return;
      setState(() => _asistencias = lista);
    });
    // Cada segundo: actualiza los relojes, rota el QR y revisa si ya se acabó el tiempo
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tic());

    if (widget.abrirCards) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirCards());
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _subSesion?.cancel();
    _subAsistencias?.cancel();
    _subCodigo?.cancel();
    super.dispose();
  }

  int get _presentes => _asistencias.where((a) => a.presente).length;

  int get _total {
    final t = widget.curso.totalEstudiantes;
    return t > 0 ? t : (_sesion?.total ?? 0);
  }

  void _tic() {
    final s = _sesion;
    if (!mounted || s == null || !s.abierta) return;
    final ahora = DateTime.now();
    if (!ahora.isBefore(s.cierraEn)) {
      _cerrar(automatico: true);
      return;
    }
    if (ahora.difference(_ultimaRotacion).inSeconds >= SesionService.segundosQr) {
      _rotar();
    }
    setState(() {}); // refresca las cuentas regresivas
  }

  Future<void> _rotar() async {
    final s = _sesion;
    if (s == null || _rotando) return;
    _rotando = true;
    _ultimaRotacion = DateTime.now();
    try {
      await _servicio.rotarToken(_cursoId, s.id, s.token);
    } catch (_) {
      // Sin conexión: se intenta de nuevo en la siguiente vuelta
    } finally {
      _rotando = false;
    }
  }

  Future<void> _cerrar({required bool automatico}) async {
    if (_cerrando) return;
    if (!automatico) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Cerrar la sesión?'),
          content: Text(
              'Quedan $_presentes de $_total presentes. Los que no marcaron quedarán como ausentes.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
          ],
        ),
      );
      if (confirmar != true) return;
    }
    if (_cerrando) return;
    _cerrando = true;
    try {
      await _servicio.cerrar(
        cursoId: _cursoId,
        sesionId: widget.sesionId,
        presentes: _presentes,
        total: _total,
      );
      _aviso(automatico ? 'Se acabó el tiempo: la sesión se cerró.' : 'Sesión cerrada.');
    } catch (_) {
      _cerrando = false;
      _aviso('No se pudo cerrar la sesión.');
    }
  }

  Future<void> _extender() async {
    final s = _sesion;
    if (s == null) return;
    try {
      await _servicio.extender(s);
    } catch (_) {
      _aviso('No se pudo extender el tiempo.');
    }
  }

  Future<void> _generarCodigo() async {
    setState(() => _generando = true);
    try {
      final nuevo = await _servicio.generarCodigo(_cursoId, widget.sesionId);
      await _subCodigo?.cancel();
      _subCodigo = _servicio.codigoUsado(_cursoId, widget.sesionId, nuevo.codigo).listen((usado) {
        if (mounted) setState(() => _codigoUsado = usado);
      });
      if (!mounted) return;
      setState(() {
        _codigo = nuevo.codigo;
        _codigoExpira = nuevo.expira;
        _codigoUsado = false;
      });
    } catch (_) {
      _aviso('No se pudo generar el código.');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _abrirLista() {
    final s = _sesion;
    if (s == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListaAsistenciaScreen(curso: widget.curso, sesion: s)),
    );
  }

  void _abrirCards() {
    final s = _sesion;
    if (!mounted) return;
    if (s == null) {
      // La sesión aún no ha cargado: se intenta en el siguiente cuadro
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirCards());
      return;
    }
    if (!s.abierta) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ModoCardsScreen(curso: widget.curso, sesion: s)),
    );
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final s = _sesion;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Toma de asistencia', style: texto.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : s == null
                ? const Center(child: Text('No se encontró la sesión.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _encabezado(texto, s),
                      const SizedBox(height: 16),
                      if (s.abierta) ...[
                        _tarjetaQr(texto, s),
                        const SizedBox(height: 12),
                        _tarjetaCodigo(texto),
                        const SizedBox(height: 12),
                      ] else ...[
                        _tarjetaCerrada(texto),
                        const SizedBox(height: 12),
                      ],
                      _tarjetaProgreso(texto),
                      const SizedBox(height: 12),
                      _tarjetaUltimos(texto),
                      const SizedBox(height: 16),
                      _acciones(texto, s),
                    ],
                  ),
      ),
    );
  }

  Widget _encabezado(TextTheme texto, Sesion s) {
    final curso = widget.curso;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (curso.codigo.isNotEmpty) ...[
                    Pildora(curso.codigo, fondo: AppColors.primarioSuave, color: AppColors.primario),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.meeting_room_outlined, size: 15, color: AppColors.textoSecundario),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(curso.salon,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(curso.titulo, style: texto.headlineMedium),
              Text('${s.tituloVisible} · inició a las ${formatoHoraDia(s.inicio)}',
                  style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(s.exigirUbicacion ? Icons.location_on : Icons.location_off_outlined,
                      size: 14,
                      color: s.exigirUbicacion ? AppColors.verde : AppColors.contorno),
                  const SizedBox(width: 4),
                  Text(
                    s.exigirUbicacion
                        ? 'GPS activo · máximo ${s.radioMetros} m de ti'
                        : 'Sin validación de GPS',
                    style: texto.bodySmall?.copyWith(
                        color: s.exigirUbicacion ? AppColors.verde : AppColors.contorno),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        s.abierta
            ? const Pildora('EN VIVO',
                fondo: Color(0x666CF8BB), color: Color(0xFF00714D), icono: Icons.circle)
            : const Pildora('CERRADA', fondo: AppColors.contenedor, color: AppColors.textoSecundario),
      ],
    );
  }

  Widget _tarjetaQr(TextTheme texto, Sesion s) {
    final ahora = DateTime.now();
    final restante = s.cierraEn.difference(ahora);
    final int segundos = (SesionService.segundosQr - ahora.difference(_ultimaRotacion).inSeconds)
        .clamp(0, SesionService.segundosQr)
        .toInt();
    final pocoTiempo = restante.inSeconds <= 60;

    return Tarjeta(
      child: Column(
        children: [
          // ---------- Tiempo de la sesión ----------
          Row(
            children: [
              Icon(Icons.timelapse, size: 18, color: pocoTiempo ? AppColors.error : AppColors.primario),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tiempo restante: ${formatoReloj(restante)}',
                  style: texto.labelMedium?.copyWith(color: pocoTiempo ? AppColors.error : null),
                ),
              ),
              TextButton(
                onPressed: _extender,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.campo,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                  textStyle: texto.labelSmall,
                ),
                child: const Text('+${SesionService.extraMinutos} min'),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.contenedor),

          // ---------- Rotación del QR ----------
          Row(
            children: [
              const Icon(Icons.security_update_good, size: 16, color: AppColors.primario),
              const SizedBox(width: 6),
              Expanded(
                child: Text('El QR cambia en $segundos s',
                    style: texto.bodySmall?.copyWith(color: AppColors.primario)),
              ),
              TextButton.icon(
                onPressed: _rotar,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: texto.labelSmall,
                ),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Cambiar ahora'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: segundos / SesionService.segundosQr,
              minHeight: 6,
              backgroundColor: AppColors.contenedor,
              color: AppColors.primarioContenedor,
            ),
          ),
          const SizedBox(height: 16),

          // ---------- QR ----------
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.campo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: s.contenidoQr,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Los estudiantes lo escanean desde la app. Una foto del QR deja de servir a los pocos segundos.',
            textAlign: TextAlign.center,
            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCodigo(TextTheme texto) {
    final codigo = _codigo;
    final expira = _codigoExpira;
    final vencido = expira != null && !DateTime.now().isBefore(expira);

    String estado = '';
    Color colorEstado = AppColors.textoSecundario;
    if (codigo != null && expira != null) {
      if (_codigoUsado) {
        estado = 'Ya fue usado';
        colorEstado = AppColors.verde;
      } else if (vencido) {
        estado = 'Venció sin usarse';
        colorEstado = AppColors.error;
      } else {
        estado = 'Vence en ${formatoReloj(expira.difference(DateTime.now()))}';
      }
    }
    final activo = codigo != null && !_codigoUsado && !vencido;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_outlined, size: 20, color: AppColors.primario),
              const SizedBox(width: 8),
              Expanded(child: Text('Código de un solo uso', style: texto.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Para un estudiante al que no le funciona la cámara. Sirve una sola vez y vence a los '
            '${SesionService.minutosCodigo} minutos.',
            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
          ),
          if (codigo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.campo,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${codigo.substring(0, 3)} - ${codigo.substring(3)}',
                      textAlign: TextAlign.center,
                      style: texto.headlineMedium?.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w800,
                        color: activo ? AppColors.primario : AppColors.contornoSuave,
                        decoration: activo ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar código',
                    icon: const Icon(Icons.content_copy, size: 18, color: AppColors.primario),
                    onPressed: activo
                        ? () async {
                            await Clipboard.setData(ClipboardData(text: codigo));
                            _aviso('Código copiado.');
                          }
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(estado,
                textAlign: TextAlign.center,
                style: texto.bodySmall?.copyWith(color: colorEstado, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _generando ? null : _generarCodigo,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              elevation: 0,
              textStyle: texto.labelMedium,
            ),
            icon: const Icon(Icons.key, size: 18),
            label: Text(codigo == null ? 'Generar código' : 'Generar otro código'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCerrada(TextTheme texto) {
    return Tarjeta(
      color: AppColors.campo,
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.textoSecundario),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Esta sesión ya está cerrada. Los estudiantes que no marcaron quedaron como ausentes.',
              style: texto.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaProgreso(TextTheme texto) {
    final total = _total;
    final double fraccion = total == 0 ? 0.0 : (_presentes / total).clamp(0.0, 1.0).toDouble();
    return Tarjeta(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_reg, size: 22, color: AppColors.verde),
              const SizedBox(width: 8),
              Expanded(child: Text('Progreso del aula', style: texto.titleMedium)),
              Pildora('$_presentes de $total · ${(fraccion * 100).round()}%',
                  fondo: const Color(0x666CF8BB), color: const Color(0xFF00714D)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraccion,
              minHeight: 8,
              backgroundColor: AppColors.contenedor,
              color: AppColors.verde,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaUltimos(TextTheme texto) {
    final presentes = _asistencias.where((a) => a.presente).toList()
      ..sort((a, b) => b.hora.compareTo(a.hora));
    final ultimos = presentes.take(3).toList();

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.primario),
              const SizedBox(width: 8),
              Expanded(child: Text('Últimos ingresos', style: texto.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          if (ultimos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Aún no se ha registrado nadie.', style: texto.bodyMedium),
            )
          else
            for (final a in ultimos)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.campo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primarioSuave,
                      child: Text(iniciales(a.nombre),
                          style: texto.labelMedium?.copyWith(color: AppColors.primario)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: texto.labelLarge?.copyWith(color: AppColors.texto)),
                          Text('${a.codigo} · ${a.metodoTexto}',
                              style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario)),
                        ],
                      ),
                    ),
                    Text(formatoHoraDia(a.hora),
                        style: texto.labelSmall?.copyWith(color: AppColors.textoSecundario)),
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle, size: 20, color: AppColors.verde),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _acciones(TextTheme texto, Sesion s) {
    ButtonStyle suave() => OutlinedButton.styleFrom(
          foregroundColor: AppColors.primario,
          backgroundColor: const Color(0xFFDCE9FF),
          side: BorderSide.none,
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: texto.labelLarge,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _abrirLista,
          style: suave(),
          icon: const Icon(Icons.format_list_bulleted, size: 18),
          label: const Text('Ver lista completa'),
        ),
        if (s.abierta) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _abrirCards,
            style: suave(),
            icon: const Icon(Icons.style_outlined, size: 18),
            label: const Text('Llamar lista con cards'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _cerrar(automatico: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              textStyle: texto.labelLarge,
            ),
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text('Cerrar sesión de asistencia'),
          ),
        ],
      ],
    );
  }
}
