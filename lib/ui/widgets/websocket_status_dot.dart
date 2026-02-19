import 'package:flutter/material.dart';
import 'package:ada_app/services/websocket/socket_service.dart';

class WebSocketStatusDot extends StatelessWidget {
  const WebSocketStatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SocketService().connectionNotifier,
      builder: (context, isConnected, child) {
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isConnected ? Colors.greenAccent : Colors.redAccent,
            shape: BoxShape.circle,
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      },
    );
  }
}
