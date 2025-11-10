import 'package:flutter/material.dart';

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

    if (!hasInternet) {
      icon = Icons.wifi_off;
      color = Colors.red;
    } else if (!hasApiConnection) {
      icon = Icons.cloud_off;
      color = Colors.orange;
    } else {
      icon = Icons.cloud_done;
      color = Colors.green;
    }

    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Icon(icon, color: color, size: 20),
    );
  }
}