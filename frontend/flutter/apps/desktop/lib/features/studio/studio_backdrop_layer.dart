import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'character_stage_presenter.dart';

/// Layer 0: Full-content-area thematic backdrop with procedural fallback and contrast scrims.
class StudioBackdropLayer extends StatelessWidget {
  const StudioBackdropLayer({
    super.key,
    required this.preset,
  });

  final StudioBackdropPreset preset;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final scrimBase = ext?.appBg ?? const Color(0xFF0F172A);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Background Image with procedural canvas fallback
        Image.asset(
          preset.assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return CustomPaint(
              painter: StudioAtmospherePainter(preset: preset),
              size: Size.infinite,
            );
          },
        ),

        // 2. Readability Scrims: Left dock scrim, right dock scrim, and central subtle radial
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  scrimBase.withValues(alpha: 0.70),
                  scrimBase.withValues(alpha: 0.15),
                  scrimBase.withValues(alpha: 0.15),
                  scrimBase.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.28, 0.72, 1.0],
              ),
            ),
          ),
        ),

        // 3. Top and bottom subtle edge vignette
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scrimBase.withValues(alpha: 0.40),
                  Colors.transparent,
                  Colors.transparent,
                  scrimBase.withValues(alpha: 0.50),
                ],
                stops: const [0.0, 0.15, 0.85, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fallback painter rendering atmospheric procedural gradient when assets are missing.
class StudioAtmospherePainter extends CustomPainter {
  const StudioAtmospherePainter({required this.preset});

  final StudioBackdropPreset preset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: preset.gradientColors,
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Subtle atmospheric ambient circle
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [
          preset.gradientColors[1].withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), size.width * 0.4, glowPaint);
  }

  @override
  bool shouldRepaint(covariant StudioAtmospherePainter oldDelegate) {
    return oldDelegate.preset != preset;
  }
}
