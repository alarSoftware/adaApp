import 'package:flutter/material.dart';

enum ConnectionType { connected, noInternet, noApi }

class AppConnectionIndicator extends StatelessWidget {
  final bool hasInternet;
  final bool hasApiConnection;

  const AppConnectionIndicator({
    super.key,
    required this.hasInternet,
    required this.hasApiConnection,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String text;

    if (!hasInternet) {
      icon = Icons.wifi_off;
      color = Colors.red;
      text = 'Sin Internet';
    } else if (!hasApiConnection) {
      icon = Icons.cloud_off;
      color = Colors.orange;
      text = 'API Desconectada';
    } else {
      icon = Icons.cloud_done;
      color = Colors.green;
      text = 'Conectado';
    }

    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}