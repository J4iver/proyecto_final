import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/curso.dart';
import '../../services/curso_service.dart';
import '../../services/importador_excel.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/campo_texto.dart';
import '../../widgets/dialogo_estudiante.dart';

class CrearCursoScreen extends StatefulWidget {
  const CrearCursoScreen({super.key});

  @override
  State<CrearCursoScreen> createState() => _CrearCursoScreenState();
}

class _CrearCursoScreenState extends State<CrearCursoScreen> {
  static const _letrasDias = ['L', 'M', 'X', 'J', 'V', 'S'];
  static const _radios = [30, 50, 100];
  static const _previa = 4; // estudiantes visibles antes de "Ver todos"

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _grupoCtrl = TextEditingController();
  final _salonCtrl = TextEditingController();
  final _servicio = CursoService();

  /// Días de clase con su horario. La clave es el día (1 = lunes ... 6 = sábado).
  final Map<int, BloqueHorario> _bloques = {};

  final List<EstudianteCurso> _estudiantes = [];
  String? _archivo;
  bool _verTodos = false;

  bool _exigirUbicacion = true;
  int _radio = 50;

  bool _leyendo = false;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _grupoCtrl.dispose();
    _salonCtrl.dispose();
    super.dispose();
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // ---------- Horario ----------

  List<BloqueHorario> get _horario =>
      _bloques.values.toList()..sort((a, b) => a.dia.compareTo(b.dia));

  /// Marca o desmarca un día. Un día nuevo arranca con las horas
  /// del último día agregado, para no repetir cuando son iguales.
  void _alternarDia(int dia) {
    setState(() {
      if (_bloques.containsKey(dia)) {
        _bloques.remove(dia);
      } else {
        final base = _bloques.isEmpty ? null : _bloques.values.last;
        _bloques[dia] = BloqueHorario(
          dia: dia,
          inicio: base?.inicio ?? 8 * 60,
          fin: base?.fin ?? 10 * 60,
        );
      }
    });
  }

  Future<void> _elegirHora(int dia, {required bool inicio}) async {
    final bloque = _bloques[dia]!;
    final actual = inicio ? bloque.inicio : bloque.fin;
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: actual ~/ 60, minute: actual % 60),
      helpText: '${Curso.nombresDiasLargos[dia - 1]}: hora de ${inicio ? 'inicio' : 'fin'}',
    );
    if (elegida == null || !_bloques.containsKey(dia)) return;
    final minutos = elegida.hour * 60 + elegida.minute;
    setState(() {
      _bloques[dia] = inicio ? bloque.copiar(inicio: minutos) : bloque.copiar(fin: minutos);
    });
  }

  // ---------- Estudiantes ----------

  Future<void> _subirExcel() async {
    // file_picker 12 o superior: pickFile() devuelve un solo archivo (o null si se cancela)
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (archivo == null) return;

    setState(() => _leyendo = true);
    try {
      final bytes = await archivo.readAsBytes();
      final importado = ImportadorExcel.leer(bytes);
      if (!mounted) return;
      setState(() {
        _estudiantes
          ..clear()
          ..addAll(importado.estudiantes);
        _archivo = archivo.name;
        _verTodos = false;
      });
      if (importado.filasOmitidas > 0) {
        _aviso('Se omitieron ${importado.filasOmitidas} filas sin código válido o repetidas.');
      }
    } catch (e) {
      _aviso(e.toString());
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
  }

  Future<void> _agregarManual() async {
    final nuevo = await showDialog<EstudianteCurso>(
      context: context,
      builder: (_) => DialogoEstudiante(
        codigosExistentes: _estudiantes.map((e) => e.codigo).toSet(),
      ),
    );
    if (nuevo == null) return;
    setState(() {
      _estudiantes.add(nuevo);
      _estudiantes.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    });
  }

  // ---------- Guardar ----------

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    String? problema;
    final malos = _horario.where((b) => b.fin <= b.inicio).toList();
    if (_bloques.isEmpty) {
      problema = 'Selecciona al menos un día de clase.';
    } else if (malos.isNotEmpty) {
      problema =
          '${Curso.nombresDiasLargos[malos.first.dia - 1]}: la hora de fin debe ser después de la de inicio.';
    } else if (_estudiantes.isEmpty) {
      problema = 'Agrega al menos un estudiante al curso.';
    }
    if (problema != null) {
      _aviso(problema);
      return;
    }

    setState(() => _guardando = true);
    try {
      await _servicio.crearCurso(
        nombre: _nombreCtrl.text,
        codigo: _codigoCtrl.text,
        grupo: _grupoCtrl.text,
        salon: _salonCtrl.text,
        horario: _horario,
        exigirUbicacion: _exigirUbicacion,
        radioMetros: _radio,
        estudiantes: _estudiantes,
      );
      if (!mounted) return;
      _aviso('Curso creado con ${_estudiantes.length} estudiantes.');
      Navigator.pop(context);
    } catch (e) {
      _aviso('No se pudo crear el curso. Revisa tu conexión y las reglas de Firestore.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    String? obligatorio(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Nuevo curso', style: texto.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ========== 1. Asignatura ==========
                _Seccion(
                  numero: 1,
                  titulo: 'Información de la asignatura',
                  child: Column(
                    children: [
                      CampoTexto(
                        etiqueta: 'Nombre de la asignatura',
                        controller: _nombreCtrl,
                        icono: Icons.auto_stories_outlined,
                        hint: 'Ej. Programación Móvil',
                        accionTeclado: TextInputAction.next,
                        validator: obligatorio,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CampoTexto(
                              etiqueta: 'Código',
                              controller: _codigoCtrl,
                              icono: Icons.tag,
                              hint: 'INF-302',
                              accionTeclado: TextInputAction.next,
                              formateadores: [_Mayusculas()],
                              validator: obligatorio,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CampoTexto(
                              etiqueta: 'Grupo',
                              controller: _grupoCtrl,
                              icono: Icons.group_work_outlined,
                              hint: 'Grupo A',
                              accionTeclado: TextInputAction.next,
                              validator: obligatorio,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CampoTexto(
                        etiqueta: 'Salón',
                        controller: _salonCtrl,
                        icono: Icons.meeting_room_outlined,
                        hint: 'Ej. Laboratorio 3B',
                        accionTeclado: TextInputAction.done,
                        validator: obligatorio,
                      ),
                    ],
                  ),
                ),

                // ========== 2. Horario ==========
                _Seccion(
                  numero: 2,
                  titulo: 'Horario y días de clase',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Días de clase', style: texto.labelMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.campo,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var d = 1; d <= 6; d++) _botonDia(texto, d),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Horario de cada día', style: texto.labelMedium),
                      const SizedBox(height: 8),
                      if (_bloques.isEmpty)
                        Text('Marca los días de clase para definir sus horas.',
                            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario))
                      else
                        for (final b in _horario) _filaHorario(texto, b),
                    ],
                  ),
                ),

                // ========== 3. Estudiantes ==========
                _Seccion(
                  numero: 3,
                  titulo: 'Lista de estudiantes',
                  child: _seccionEstudiantes(texto),
                ),

                // ========== 4. Seguridad ==========
                _Seccion(
                  numero: 4,
                  titulo: 'Seguridad de asistencia',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primarioSuave,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.location_on_outlined,
                                size: 22, color: AppColors.primario),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Validar ubicación (GPS)', style: texto.labelMedium),
                                Text('El estudiante debe estar cerca del docente al escanear',
                                    style: texto.bodySmall
                                        ?.copyWith(color: AppColors.textoSecundario)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _exigirUbicacion,
                            activeTrackColor: AppColors.verde,
                            onChanged: (v) => setState(() => _exigirUbicacion = v),
                          ),
                        ],
                      ),
                      if (_exigirUbicacion) ...[
                        const SizedBox(height: 12),
                        Text('Distancia máxima permitida', style: texto.labelMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final r in _radios)
                              ChoiceChip(
                                label: Text('$r m'),
                                selected: _radio == r,
                                onSelected: (_) => setState(() => _radio = r),
                                showCheckmark: false,
                                shape: const StadiumBorder(),
                                side: BorderSide.none,
                                backgroundColor: AppColors.campo,
                                selectedColor: AppColors.primarioContenedor,
                                labelStyle: texto.labelMedium?.copyWith(
                                  color: _radio == r ? Colors.white : AppColors.textoSecundario,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _guardando ? null : _crear,
                  child: _guardando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 22),
                            SizedBox(width: 8),
                            Text('Crear curso'),
                          ],
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Los estudiantes verán el curso cuando inicien sesión con su código.',
                  textAlign: TextAlign.center,
                  style: texto.bodySmall?.copyWith(color: AppColors.contorno),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonDia(TextTheme texto, int dia) {
    final activo = _bloques.containsKey(dia);
    return Tooltip(
      message: Curso.nombresDias[dia - 1],
      child: GestureDetector(
        onTap: () => _alternarDia(dia),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? AppColors.primarioContenedor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            _letrasDias[dia - 1],
            style: texto.labelMedium?.copyWith(
              color: activo ? Colors.white : AppColors.textoSecundario,
              fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Fila de un día: nombre, hora de inicio, hora de fin y duración.
  Widget _filaHorario(TextTheme texto, BloqueHorario b) {
    final duracion = b.fin - b.inicio;
    final String textoDuracion;
    if (duracion <= 0) {
      textoDuracion = 'Revisa las horas';
    } else if (duracion % 60 == 0) {
      textoDuracion = '${duracion ~/ 60} h';
    } else {
      textoDuracion = '${duracion ~/ 60} h ${duracion % 60} min';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Curso.nombresDiasLargos[b.dia - 1], style: texto.labelMedium),
                Text(
                  textoDuracion,
                  style: texto.bodySmall?.copyWith(
                    color: duracion <= 0 ? AppColors.error : AppColors.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          _botonHora(texto, b.inicio, () => _elegirHora(b.dia, inicio: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('a', style: texto.bodySmall?.copyWith(color: AppColors.contorno)),
          ),
          _botonHora(texto, b.fin, () => _elegirHora(b.dia, inicio: false)),
        ],
      ),
    );
  }

  Widget _botonHora(TextTheme texto, int minutos, VoidCallback alTocar) {
    return TextButton(
      onPressed: alTocar,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primario,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      child: Text(formatoHora(minutos)),
    );
  }

  Widget _seccionEstudiantes(TextTheme texto) {
    final visibles = _verTodos ? _estudiantes : _estudiantes.take(_previa).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------- Archivo ----------
        if (_archivo != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.campo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.verde,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_archivo!,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: texto.labelMedium),
                      Text('Columnas leídas: código, nombre y correo',
                          style: texto.bodySmall?.copyWith(color: AppColors.verde)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _leyendo ? null : _subirExcel,
                  style: TextButton.styleFrom(textStyle: texto.labelSmall),
                  child: const Text('Reemplazar'),
                ),
              ],
            ),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: _leyendo ? null : _subirExcel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primario,
              backgroundColor: AppColors.campo,
              side: const BorderSide(color: AppColors.contornoSuave),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _leyendo
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file, size: 20, color: AppColors.verde),
            label: Text(_leyendo ? 'Leyendo archivo…' : 'Subir lista en Excel (.xlsx)'),
          ),
          const SizedBox(height: 6),
          Text(
            'El archivo debe tener una columna de código (10 dígitos) y una de nombre. '
            'El correo es opcional. Las demás columnas se ignoran.',
            style: texto.bodySmall?.copyWith(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 12),
        ],

        // ---------- Lista ----------
        Row(
          children: [
            const Icon(Icons.groups_outlined, size: 18, color: AppColors.primario),
            const SizedBox(width: 8),
            Text('Estudiantes', style: texto.labelMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.contenedor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${_estudiantes.length}',
                  style: texto.labelSmall?.copyWith(color: AppColors.primario)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final e in visibles) _filaEstudiante(texto, e),
        if (_estudiantes.length > _previa)
          TextButton(
            onPressed: () => setState(() => _verTodos = !_verTodos),
            child: Text(_verTodos ? 'Ver menos' : 'Ver los ${_estudiantes.length}'),
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _agregarManual,
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: const Text('Agregar estudiante a mano'),
        ),
      ],
    );
  }

  Widget _filaEstudiante(TextTheme texto, EstudianteCurso e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primarioSuave,
            child: Text(iniciales(e.nombre),
                style: texto.labelSmall?.copyWith(color: AppColors.primario)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nombre,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: texto.labelMedium),
                Text(
                  e.email.isEmpty ? e.codigo : '${e.codigo} • ${e.email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texto.bodySmall?.copyWith(color: AppColors.contorno),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar de la lista',
            icon: const Icon(Icons.close, size: 18, color: AppColors.contorno),
            onPressed: () => setState(() {
              _estudiantes.remove(e);
            }),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta blanca de una sección del formulario, con su número y título.
class _Seccion extends StatelessWidget {
  final int numero;
  final String titulo;
  final Widget child;
  const _Seccion({required this.numero, required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primarioSuave,
                  child: Text('$numero',
                      style: texto.labelSmall?.copyWith(color: AppColors.primario)),
                ),
                const SizedBox(width: 8),
                Text(titulo, style: texto.labelMedium?.copyWith(color: AppColors.contorno)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Convierte a mayúsculas lo que se escribe (para el código de la asignatura).
class _Mayusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    return nuevo.copyWith(text: nuevo.text.toUpperCase());
  }
}
