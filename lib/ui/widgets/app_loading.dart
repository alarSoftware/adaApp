import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  final String? message;
  final bool isSmall;

  const AppLoading({
    super.key,
    this.message,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSmall) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.grey[700]),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}