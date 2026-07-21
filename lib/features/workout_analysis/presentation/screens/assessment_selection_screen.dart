import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../domain/models/assessment_models.dart';
import '../providers/selected_assessment_provider.dart';
import 'assessment_live_screen.dart';

class AssessmentSelectionScreen extends ConsumerWidget {
  const AssessmentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    return AppScaffoldShell(
      title: localizations.assessmentMode,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      body: ListView(
        children: [
          Text(
            localizations.assessmentDisclaimer,
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 16),
          _AssessmentCard(
            title: localizations.assessmentTitle('squat'),
            subtitle: localizations.squatAssessmentSubtitle,
            icon: Icons.accessibility_new_rounded,
            onTap: () => _openAssessment(
              context,
              ref,
              const AssessmentSelection(type: AssessmentType.squat),
            ),
          ),
          const SizedBox(height: 12),
          _AssessmentCard(
            title: localizations.assessmentTitle('balance'),
            subtitle: localizations.balanceAssessmentSubtitle,
            icon: Icons.balance_rounded,
            onTap: () => _showBalanceSidePicker(context, ref),
          ),
          const SizedBox(height: 12),
          _AssessmentCard(
            title: localizations.assessmentTitle('shoulderMobility'),
            subtitle: localizations.shoulderAssessmentSubtitle,
            icon: Icons.sports_gymnastics_rounded,
            onTap: () => _openAssessment(
              context,
              ref,
              const AssessmentSelection(type: AssessmentType.shoulderMobility),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBalanceSidePicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final localizations = AppLocalizations.of(context);
    final side = await showModalBottomSheet<AssessmentSide>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localizations.chooseStandingFoot,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, AssessmentSide.left),
                child: Text(localizations.leftFoot),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, AssessmentSide.right),
                child: Text(localizations.rightFoot),
              ),
            ],
          ),
        ),
      ),
    );
    if (side == null || !context.mounted) {
      return;
    }
    await _openAssessment(
      context,
      ref,
      AssessmentSelection(type: AssessmentType.balance, balanceSide: side),
    );
  }

  Future<void> _openAssessment(
    BuildContext context,
    WidgetRef ref,
    AssessmentSelection selection,
  ) async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!context.mounted) {
      return;
    }
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).assessmentCameraPermissionRequired,
          ),
        ),
      );
      return;
    }

    ref.read(selectedAssessmentProvider.notifier).state = selection;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssessmentLiveScreen()),
    );
    ref.read(selectedAssessmentProvider.notifier).state = null;
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: Colors.greenAccent, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
