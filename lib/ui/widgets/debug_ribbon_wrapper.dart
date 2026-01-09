import 'package:flutter/material.dart';
import 'package:ada_app/services/api/api_config_service.dart';

class DebugRibbonWrapper extends StatefulWidget {
  final Widget child;

  const DebugRibbonWrapper({super.key, required this.child});

  @override
  State<DebugRibbonWrapper> createState() => _DebugRibbonWrapperState();
}

class _DebugRibbonWrapperState extends State<DebugRibbonWrapper> {
  @override
  void initState() {
    super.initState();
    // Iniciar chequeo para poblar el notifier si es necesario
    ApiConfigService.getBaseUrl();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: ApiConfigService.urlNotifier,
      builder: (context, currentUrl, child) {
        // Si es nulo (cargando) o es igual al default, no mostrar ribbon
        final isDebug =
            currentUrl != null && currentUrl != ApiConfigService.defaultBaseUrl;

        if (!isDebug) return widget.child;

        return Stack(
          textDirection: TextDirection.ltr,
          children: [
            widget.child,
            Positioned(
              top: 0,
              right: 0,
              child: Banner(
                message: 'DEBUG',
                location: BannerLocation.topEnd,
                color: Colors.red.withOpacity(0.8),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
