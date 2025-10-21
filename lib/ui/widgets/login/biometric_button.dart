import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class BiometricButton extends StatelessWidget {
  final VoidCallback onPressed;

  const BiometricButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: 'Usar autenticación biométrica para iniciar sesión',
      child: Center(
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.secondary,
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(35),
              child: Center(
                child: Icon(
                  Icons.fingerprint,
                  color: AppColors.secondary,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}