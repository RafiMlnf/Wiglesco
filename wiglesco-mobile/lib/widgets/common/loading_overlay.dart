import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../services/on_device/pipeline.dart';

class LoadingOverlay extends StatelessWidget {
  final String currentStep;
  final int currentStepIndex;
  const LoadingOverlay({
    super.key,
    required this.currentStep,
    this.currentStepIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: AppColors.background.withOpacity(0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thin elegant spinner
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 28),

              // Step text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  currentStep.toUpperCase(),
                  key: ValueKey(currentStep),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(duration: 300.ms),
              ),
              const SizedBox(height: 8),

              // Step description
              Text(
                'STEP ${currentStepIndex + 1} OF ${kPipelineSteps.length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
