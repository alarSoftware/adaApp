import 'package:flutter/material.dart';

class AppLoadingMore extends StatelessWidget {
  const AppLoadingMore({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(color: Colors.grey[700]),
      ),
    );
  }
}