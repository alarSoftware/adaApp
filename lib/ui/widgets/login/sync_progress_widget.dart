import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class SyncProgressWidget extends StatelessWidget {
  final double progress;
  final String currentStep;
  final List<String> completedSteps;

  const SyncProgressWidget({
    super.key,
    required this.progress,
    required this.currentStep,
    required this.completedSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          minHeight: 6,
        ),
        if (currentStep.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            currentStep,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (completedSteps.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCompletedSteps(),
        ],
      ],
    );
  }

  Widget _buildCompletedSteps() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: completedSteps
            .map((step) => Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  step,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ))
            .toList(),
      ),
    );
  }
}