import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;
import '../models/curso.dart';

class ResultadoImportacion {
  final List<EstudianteCurso> estudiantes;
  final int filasOmitidas; // filas sin código válido o repetidas
  const ResultadoImportacion(this.estudiantes, this.filasOmitidas);
}

class ImportacionError implements Exception {
  final String mensaje;
  ImportacionError(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Lee un .xlsx y saca la lista de estudiantes.
/// Busca las columnas por el nombre del encabezado, no por posición,
/// y solo toma código, nombre, correo y programa: el resto se ignora.
class ImportadorExcel {
  static ResultadoImportacion leer(Uint8List bytes) {
    final xls.Excel libro;
    try {
      libro = xls.Excel.decodeBytes(bytes);
    } catch (_) {
      throw ImportacionError(
          'No se pudo leer el archivo. Debe ser .xlsx (si es .xls, ábrelo en Excel y guárdalo como .xlsx).');
    }

    for (final hoja in libro.tables.values) {
      final filas = hoja.rows;

      // Buscar la fila de encabezados en las primeras 10 filas
      for (var i = 0; i < filas.length && i < 10; i++) {
        final encabezados = filas[i].map((c) => _normalizar(_texto(c))).toList();
        final colCodigo = encabezados.indexWhere((h) => h.contains('CODIGO') || h.contains('CARNET'));
        final colNombre = encabezados.indexWhere((h) => h.contains('NOMBRE'));
        if (colCodigo == -1 || colNombre == -1) continue;

        final colCorreo = encabezados.indexWhere((h) => h.contains('MAIL') || h.contains('CORREO'));
        final colPrograma = encabezados.indexWhere((h) => h.contains('PROGRAMA'));

        final estudiantes = <EstudianteCurso>[];
        final vistos = <String>{};
        var omitidas = 0;

        for (final fila in filas.skip(i + 1)) {
          final codigo = _soloDigitos(_celda(fila, colCodigo));
          final nombre = _celda(fila, colNombre);
          if (codigo.isEmpty && nombre.isEmpty) continue; // fila vacía
          if (codigo.length != 10 || nombre.isEmpty || !vistos.add(codigo)) {
            omitidas++;
            continue;
          }
          estudiantes.add(EstudianteCurso(
            codigo: codigo,
            nombre: nombre,
            email: _celda(fila, colCorreo).toLowerCase(),
            programa: _celda(fila, colPrograma),
          ));
        }

        if (estudiantes.isEmpty) {
          throw ImportacionError('El archivo no tiene estudiantes con código de 10 dígitos.');
        }
        estudiantes.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return ResultadoImportacion(estudiantes, omitidas);
      }
    }

    throw ImportacionError(
        'No se encontraron las columnas. El archivo debe tener una columna de código y una de nombre.');
  }

  static String _celda(List<xls.Data?> fila, int col) {
    if (col < 0 || col >= fila.length) return '';
    return _texto(fila[col]);
  }

  /// Valor de la celda como texto. Los números llegan como "4245172970.0".
  static String _texto(xls.Data? celda) {
    var t = celda?.value?.toString().trim() ?? '';
    if (RegExp(r'^\d+\.0+$').hasMatch(t)) t = t.split('.').first;
    return t;
  }

  static String _soloDigitos(String t) => t.replaceAll(RegExp(r'\D'), '');

  /// Mayúsculas, sin tildes, espacios ni guiones bajos: "Código Estudiante" -> "CODIGOESTUDIANTE".
  static String _normalizar(String t) {
    const con = 'ÁÉÍÓÚÜÑ';
    const sin = 'AEIOUUN';
    var r = t.toUpperCase();
    for (var i = 0; i < con.length; i++) {
      r = r.replaceAll(con[i], sin[i]);
    }
    return r.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
