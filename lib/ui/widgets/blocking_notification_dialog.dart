import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ada_app/models/notification_model.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/utils/logger.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';


class BlockingNotificationDialog extends StatefulWidget {
  final NotificationModel notification;
  final bool dismissible;

  const BlockingNotificationDialog({
    super.key,
    required this.notification,
    this.dismissible = false,
  });

  @override
  State<BlockingNotificationDialog> createState() =>
      _BlockingNotificationDialogState();
}

class _BlockingNotificationDialogState
    extends State<BlockingNotificationDialog> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  bool _downloadComplete = false;
  bool _downloadError = false;
  bool _waitingForInstall = false;
  String _currentVersion = '...';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadVersion();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = packageInfo.version;
        });
      }
    } catch (e) {
      AppLogger.e('Error cargando versión', e);
    }
  }

  void _resetToInitialState({String? message}) {
    if (!mounted) return;
    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _downloadComplete = false;
      _downloadError = false;
      _statusMessage = message ?? '';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando el usuario vuelve a la app después del diálogo de instalación
    if (state == AppLifecycleState.resumed && _waitingForInstall) {
      _waitingForInstall = false;
      // Pequeño delay para que el sistema termine de procesar
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          // Si la versión no cambió, el usuario canceló la instalación
          if (packageInfo.version == _currentVersion) {
            AppLogger.i('BLOCKING_DIALOG: Instalación cancelada por el usuario (versión sin cambio)');
            _resetToInitialState();
          }
        } catch (e) {
          AppLogger.e('BLOCKING_DIALOG: Error verificando versión post-instalación', e);
          _resetToInitialState();
        }
      });
    }
  }

  Future<void> _startDownload() async {
    final String? blockingUrl = widget.notification.blockingUrl;
    
    // Si hay una URL pero no parece un APK (ej: WhatsApp), la abrimos externamente
    if (blockingUrl != null && 
        blockingUrl.isNotEmpty && 
        !blockingUrl.toLowerCase().contains('.apk') &&
        !blockingUrl.toLowerCase().contains('/api/get_apk')) {
      final uri = Uri.tryParse(blockingUrl);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return; // Salimos, no es una descarga de APK
        } catch (e) {
          AppLogger.e('Error lanzando URL externa', e);
          _resetToInitialState(message: 'No se pudo abrir el enlace');
          return;
        }
      }
    }

    try {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        setState(() {
          _isDownloading = true;
          _statusMessage = 'Permiso necesario para instalar actualizaciones';
        });

        // Intentar solicitarlo
        final result = await Permission.requestInstallPackages.request();
        
        if (!result.isGranted) {
          // Si sigue sin estar concedido, abrir los ajustes directamente
          setState(() {
            _statusMessage = 'Por favor, activa "Instalar aplicaciones desconocidas" para AdaApp';
          });
          
          await openAppSettings();
          
          // No continuamos, el usuario volverá después de cambiar el ajuste
          setState(() => _isDownloading = false);
          return;
        }
      }
    } catch (e) {
      AppLogger.e('Error solicitando permiso de instalación', e);
      _resetToInitialState(message: 'Error al solicitar permiso de instalación');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Iniciando descarga...';
      _downloadError = false;
    });

    try {
      // Priorizamos la URL que viene en la notificación si es un APK
      final apkUrl = (blockingUrl != null && blockingUrl.isNotEmpty) 
          ? (blockingUrl.startsWith('http') ? blockingUrl : await ApiConfigService.getFullUrl(blockingUrl))
          : await ApiConfigService.getFullUrl('/api/get_apk');

      // Validación PRE-Descarga: Verificamos headers sin descargar todo el archivo
      try {
        AppLogger.i('DEBUG_OTA: Verificando URL (HEAD): $apkUrl');
        final response = await http.head(Uri.parse(apkUrl)).timeout(const Duration(seconds: 10));
        
        AppLogger.i('DEBUG_OTA: Status Code: ${response.statusCode}');
        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        final contentLength = response.headers['content-length'];
        AppLogger.i('DEBUG_OTA: Content-Type: $contentType, Size: $contentLength');
        
        if (response.statusCode != 200) {
          // Si HEAD falla (algunos servidores no lo soportan), intentamos GET ligero
          AppLogger.w('DEBUG_OTA: HEAD falló, intentando GET limitado...');
          final getCheck = await http.get(Uri.parse(apkUrl)).timeout(const Duration(seconds: 5));
          if (getCheck.statusCode != 200) throw 'Servidor devolvió error ${getCheck.statusCode}';
          if (getCheck.headers['content-type']?.contains('text/html') ?? false) {
             throw 'El servidor envió HTML en lugar de APK.';
          }
        } else {
          if (contentType.contains('text/html')) {
            throw 'El servidor envió una página web (HTML) en lugar del instalador.';
          }
        }
      } catch (e) {
        AppLogger.e('DEBUG_OTA: Error en validación previa: $e');
        // Si no hay red o el servidor no responde, cancelar inmediatamente
        _resetToInitialState(message: 'No se pudo conectar al servidor. Verifica tu conexión.');
        return;
      }

      AppLogger.i('BLOCKING_DIALOG: Iniciando descarga de APK desde: $apkUrl');

      OtaUpdate()
          .execute(
            apkUrl,
            destinationFilename: 'ada_update.apk', // Forzamos extensión .apk
          )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          setState(() {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                final progress = double.tryParse(event.value ?? '0') ?? 0;
                _downloadProgress = progress / 100.0;
                _statusMessage = 'Descargando... ${progress.toStringAsFixed(0)}%';
                break;
              case OtaStatus.INSTALLING:
                _downloadComplete = true;
                _waitingForInstall = true;
                _statusMessage = 'Instalando actualización...';
                break;
              case OtaStatus.ALREADY_RUNNING_ERROR:
                _isDownloading = false;
                _statusMessage = 'Ya hay una descarga en curso';
                break;
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _isDownloading = false;
                _downloadProgress = 0.0;
                _downloadComplete = false;
                _downloadError = false;
                _statusMessage = 'Permiso denegado: Activa "Instalar apps desconocidas"';
                break;
              case OtaStatus.INTERNAL_ERROR:
              case OtaStatus.DOWNLOAD_ERROR:
              case OtaStatus.CHECKSUM_ERROR:
              case OtaStatus.INSTALLATION_ERROR:
                _isDownloading = false;
                _downloadProgress = 0.0;
                _downloadComplete = false;
                _downloadError = false;
                _statusMessage = 'Error: ${event.value ?? "Intenta de nuevo"}';
                break;
              case OtaStatus.INSTALLATION_DONE:
                _downloadComplete = true;
                _statusMessage = 'Instalación terminada';
                break;
              case OtaStatus.CANCELED:
                _isDownloading = false;
                _downloadProgress = 0.0;
                _downloadComplete = false;
                _downloadError = false;
                _statusMessage = '';
                break;
            }
          });
        },
        onError: (e) {
          AppLogger.e('BLOCKING_DIALOG: Error crítico en OTA stream', e);
          _resetToInitialState(message: 'Error crítico. Intenta de nuevo.');
        },
      );
    } catch (e) {
      AppLogger.e('BLOCKING_DIALOG: Error al iniciar descarga', e);
      _resetToInitialState(message: 'Error al iniciar. Intenta de nuevo.');
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.dismissible,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icono con pulso
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFe94560).withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.system_update_rounded,
                            size: 48,
                            color: Color(0xFFff6b6b),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Título
                      Text(
                        widget.notification.title.isNotEmpty
                            ? widget.notification.title
                            : 'Actualización Obligatoria',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Mensaje
                      Text(
                        widget.notification.message.isNotEmpty
                            ? widget.notification.message
                            : 'Nueva versión disponible. Actualiza para continuar.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // Progreso central
                      if (_isDownloading) ...[
                        _buildProgressBar(),
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: _downloadError
                                ? const Color(0xFFff6b6b)
                                : Colors.white.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_downloadError || _downloadComplete) ...[
                          const SizedBox(height: 20),
                          _buildDownloadButton(),
                        ] else ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => _resetToInitialState(),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white.withOpacity(0.4)),
                            ),
                          ),
                        ],
                      ] else ...[
                        if (widget.notification.blockingUrl != null && 
                            widget.notification.blockingUrl!.isNotEmpty)
                          _buildDownloadButton(),
                        if (widget.dismissible && !_isDownloading) ...[
                          const SizedBox(height: 12),
                          _buildCloseButton(),
                        ],
                      ],


                      const SizedBox(height: 20),
                      Text(
                        'Versión actual: ${_getCurrentVersion()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _downloadComplete ? null : _downloadProgress,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(
              _downloadError ? const Color(0xFFe94560) : const Color(0xFF00d2ff),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton() {
    final String? blockingUrl = widget.notification.blockingUrl;
    final bool isApk = blockingUrl == null || 
                      blockingUrl.isEmpty || 
                      blockingUrl.toLowerCase().contains('.apk') ||
                      blockingUrl.toLowerCase().contains('/api/get_apk');

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _startDownload,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00d2ff),
          foregroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_downloadError ? Icons.refresh : (isApk ? Icons.download : Icons.open_in_new), size: 20),
            const SizedBox(width: 8),
            Text(
              _downloadError ? 'Reintentar' : (isApk ? 'Actualizar ahora' : 'Acceder enlace'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(
        'Quizás más tarde',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getCurrentVersion() => _currentVersion;
}
