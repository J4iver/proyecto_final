import 'dart:async';
import 'package:geolocator/geolocator.dart';

class UbicacionError implements Exception {
  final String mensaje;
  UbicacionError(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Lee el GPS del celular, pidiendo el permiso si hace falta.
class UbicacionService {
  static Future<Position> actual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw UbicacionError('La ubicación (GPS) del celular está apagada. Actívala e inténtalo de nuevo.');
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      throw UbicacionError(
          'La app no tiene permiso para usar tu ubicación. Actívalo en los ajustes del celular.');
    }

    try {
      return await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw UbicacionError('El GPS tardó demasiado en responder. Inténtalo de nuevo.');
    } catch (_) {
      throw UbicacionError('No se pudo leer tu ubicación.');
    }
  }

  /// Distancia en metros entre dos puntos.
  static double distancia(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
