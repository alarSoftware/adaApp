// widgets/gps_navigation_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ada_app/ui/theme/colors.dart';

class GPSNavigationWidget {

  static Future<void> abrirUbicacionEnMapa(
      BuildContext context,
      double latitud,
      double longitud
      ) async {
    // Abrir Google Maps directamente
    await _abrirGoogleMaps(context, latitud, longitud);
  }

  // Google Maps directo (sin verificaciones previas)
  static Future<void> _abrirGoogleMaps(
      BuildContext context,
      double latitud,
      double longitud
      ) async {

    final url = 'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud';
    print('🗺️ Abriendo Google Maps: $url');

    try {
      final uri = Uri.parse(url);

      // Abrir directamente sin verificar canLaunchUrl
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      print('🗺️ Google Maps launched: $launched');

      if (!launched) {
        _mostrarError(context, 'No se pudo abrir Google Maps');
      }

    } catch (e) {
      print('🗺️ Error al abrir Google Maps: $e');
      _mostrarError(context, 'Error al abrir Google Maps: $e');
    }
  }

  static void _mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}