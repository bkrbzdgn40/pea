import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../challenges/domain/models/medal_tier.dart';

class AchievementBadgeMark extends StatelessWidget {
  const AchievementBadgeMark({
    super.key,
    required this.achievementId,
    required this.accent,
    required this.secret,
    this.emphasized = false,
  });

  final String achievementId;
  final Color accent;
  final bool secret;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final size = emphasized ? 58.0 : 48.0;
    final localizations = AppLocalizations.of(context);
    final title = localizations.achievementTitle(achievementId);

    return Semantics(
      label: localizations.achievementBadgeSemanticLabel(title),
      image: true,
      child: ExcludeSemantics(
        child: _RewardReveal(
          emphasized: emphasized,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: _AchievementBadgePainter(
                    accent: accent,
                    secret: secret,
                    emphasized: emphasized,
                  ),
                ),
                Icon(
                  achievementIconForId(achievementId),
                  color: accent,
                  size: emphasized ? 27 : 23,
                ),
                if (secret)
                  Positioned(
                    right: emphasized ? -1 : -2,
                    top: emphasized ? -1 : -2,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.achievementSecret,
                      size: emphasized ? 15 : 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MedalBadgeMark extends StatelessWidget {
  const MedalBadgeMark({
    super.key,
    required this.tier,
    this.emphasized = false,
  });

  final MedalTier tier;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = medalColorForTier(tier);
    final size = emphasized ? 60.0 : 50.0;
    final label = medalLabelForTier(AppLocalizations.of(context), tier);

    return Semantics(
      label: AppLocalizations.of(context).medalSemanticLabel(label),
      image: true,
      child: ExcludeSemantics(
        child: _RewardReveal(
          emphasized: emphasized || tier == MedalTier.gold,
          child: SizedBox(
            width: size,
            height: size + 8,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MedalBadgePainter(color: color, tier: tier),
                  ),
                ),
                Positioned(
                  top: size * 0.25,
                  child: Icon(
                    tier == MedalTier.silver
                        ? Icons.military_tech_rounded
                        : Icons.workspace_premium_rounded,
                    color: color,
                    size: emphasized ? 28 : 24,
                  ),
                ),
                if (tier == MedalTier.gold)
                  Positioned(
                    right: emphasized ? 3 : 2,
                    top: emphasized ? 8 : 7,
                    child: Icon(Icons.star_rounded, size: 14, color: color),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedRewardProgress extends StatelessWidget {
  const AnimatedRewardProgress({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 8,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final duration = AppMotion.resolveDuration(
      context,
      AppMotionDurations.emphasized,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: duration,
      curve: AppMotion.resolveCurve(context, AppMotionCurves.standard),
      builder: (context, animatedValue, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: LinearProgressIndicator(
            minHeight: minHeight,
            value: animatedValue,
            backgroundColor: backgroundColor,
            color: color,
          ),
        );
      },
    );
  }
}

class _RewardReveal extends StatelessWidget {
  const _RewardReveal({required this.child, required this.emphasized});

  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.resolveDuration(
      context,
      emphasized ? AppMotionDurations.celebration : AppMotionDurations.standard,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: AppMotion.resolveCurve(context, AppMotionCurves.emphasized),
      child: child,
      builder: (context, value, child) {
        final scale = 0.92 + (0.08 * value);
        return Opacity(
          opacity: 0.6 + (0.4 * value),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

class _AchievementBadgePainter extends CustomPainter {
  const _AchievementBadgePainter({
    required this.accent,
    required this.secret,
    required this.emphasized,
  });

  final Color accent;
  final bool secret;
  final bool emphasized;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final outer = _regularPolygon(center, radius - 1, 6, -math.pi / 2);
    final inner = _regularPolygon(center, radius - 5, 6, -math.pi / 2);
    final bounds = Offset.zero & size;

    final fill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.1,
        colors: [
          accent.withValues(alpha: emphasized ? 0.28 : 0.20),
          accent.withValues(alpha: 0.055),
        ],
      ).createShader(bounds);
    canvas.drawPath(outer, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = secret ? 2.1 : (emphasized ? 1.8 : 1.35)
      ..color = accent.withValues(alpha: secret ? 0.88 : 0.62);
    canvas.drawPath(outer, border);

    final innerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: 0.20);
    canvas.drawPath(inner, innerBorder);

    if (emphasized) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = accent.withValues(alpha: 0.16);
      canvas.drawPath(outer, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _AchievementBadgePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.secret != secret ||
        oldDelegate.emphasized != emphasized;
  }
}

class _MedalBadgePainter extends CustomPainter {
  const _MedalBadgePainter({required this.color, required this.tier});

  final Color color;
  final MedalTier tier;

  @override
  void paint(Canvas canvas, Size size) {
    final discRadius = size.width * 0.34;
    final center = Offset(size.width / 2, size.height * 0.53);

    final ribbonPaint = Paint()..color = color.withValues(alpha: 0.48);
    final leftRibbon = Path()
      ..moveTo(center.dx - discRadius * 0.66, center.dy - discRadius * 0.55)
      ..lineTo(center.dx - discRadius * 1.10, 0)
      ..lineTo(center.dx - discRadius * 0.18, size.height * 0.17)
      ..lineTo(center.dx - discRadius * 0.08, center.dy - discRadius * 0.36)
      ..close();
    final rightRibbon = Path()
      ..moveTo(center.dx + discRadius * 0.66, center.dy - discRadius * 0.55)
      ..lineTo(center.dx + discRadius * 1.10, 0)
      ..lineTo(center.dx + discRadius * 0.18, size.height * 0.17)
      ..lineTo(center.dx + discRadius * 0.08, center.dy - discRadius * 0.36)
      ..close();
    canvas.drawPath(leftRibbon, ribbonPaint);
    canvas.drawPath(rightRibbon, ribbonPaint);

    final discBounds = Rect.fromCircle(center: center, radius: discRadius);
    final highlightMix = tier == MedalTier.silver ? 0.26 : 0.16;
    final fill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.0,
        colors: [
          Color.lerp(color, Colors.white, highlightMix)!,
          color.withValues(alpha: 0.22),
        ],
      ).createShader(discBounds);
    canvas.drawCircle(center, discRadius, fill);

    final outerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = tier == MedalTier.gold ? 2.6 : 1.8
      ..color = color.withValues(alpha: 0.92);
    canvas.drawCircle(center, discRadius, outerBorder);

    final innerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.38);
    canvas.drawCircle(center, discRadius - 4, innerBorder);

    if (tier == MedalTier.gold) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
        ..color = color.withValues(alpha: 0.18);
      canvas.drawCircle(center, discRadius, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _MedalBadgePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.tier != tier;
  }
}

Path _regularPolygon(Offset center, double radius, int sides, double rotation) {
  final path = Path();
  for (var index = 0; index < sides; index++) {
    final angle = rotation + ((math.pi * 2 * index) / sides);
    final point = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    if (index == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  return path;
}

Color achievementAccentForId(String id) {
  return switch (id) {
    'first_reliable_analysis' ||
    'reliable_sessions_5' => AppColors.achievementTrust,
    'exercise_explorer_3' ||
    'balanced_explorer' => AppColors.achievementExplore,
    'guide_completed' => AppColors.achievementReturn,
    'controlled_tempo' || 'rhythm_30_days' => AppColors.achievementRhythm,
    'planned_workout_completed' ||
    'planned_workouts_5' => AppColors.achievementPlan,
    'return_after_14_days' => AppColors.achievementReturn,
    'golden_week' => AppColors.achievementSecret,
    _ => AppColors.analysisAccent,
  };
}

IconData achievementIconForId(String id) {
  return switch (id) {
    'first_reliable_analysis' => Icons.verified_rounded,
    'reliable_sessions_5' => Icons.shield_rounded,
    'exercise_explorer_3' => Icons.explore_rounded,
    'guide_completed' => Icons.menu_book_rounded,
    'controlled_tempo' => Icons.speed_rounded,
    'planned_workout_completed' => Icons.task_alt_rounded,
    'planned_workouts_5' => Icons.event_repeat_rounded,
    'balanced_explorer' => Icons.accessibility_new_rounded,
    'return_after_14_days' => Icons.replay_rounded,
    'rhythm_30_days' => Icons.local_fire_department_rounded,
    'golden_week' => Icons.auto_awesome_rounded,
    _ => Icons.workspace_premium_rounded,
  };
}

bool isSecretAchievementId(String id) {
  return id == 'return_after_14_days' ||
      id == 'rhythm_30_days' ||
      id == 'golden_week';
}

Color medalColorForTier(MedalTier tier) {
  return switch (tier) {
    MedalTier.bronze => AppColors.medalBronze,
    MedalTier.silver => AppColors.medalSilver,
    MedalTier.gold => AppColors.medalGold,
    MedalTier.none => AppColors.mutedForeground,
  };
}

String medalLabelForTier(AppLocalizations localizations, MedalTier tier) {
  return switch (tier) {
    MedalTier.bronze => localizations.bronzeMedal,
    MedalTier.silver => localizations.silverMedal,
    MedalTier.gold => localizations.goldMedal,
    MedalTier.none => localizations.medalNotEarned,
  };
}
