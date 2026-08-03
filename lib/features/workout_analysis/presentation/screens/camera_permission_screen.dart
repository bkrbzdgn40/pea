import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_button.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/selected_exercise_provider.dart';
import '../widgets/analysis_selection_required_view.dart';
import 'exercise_selection_screen.dart';
import 'preparation_screen.dart';

class CameraPermissionScreen extends ConsumerStatefulWidget {
  const CameraPermissionScreen({super.key});

  @override
  ConsumerState<CameraPermissionScreen> createState() =>
      _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends ConsumerState<CameraPermissionScreen>
    with WidgetsBindingObserver {
  PermissionStatus? _status;
  bool _isChecking = false;
  bool _hasNavigated = false;
  bool _hasRequestedPermission = false;

  bool get _isBlocked {
    final status = _status;
    return status?.isPermanentlyDenied == true || status?.isRestricted == true;
  }

  bool get _isBusy => _isChecking;

  bool get _hasAnalysisSelection {
    final selectedExercise = ref.read(selectedExerciseProvider);
    final activeExercise = ref.read(activeAnalysisExerciseProvider);

    return selectedExercise != null && activeExercise != null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAnalysisSelection) {
        return;
      }
      unawaited(_checkPermission(continueIfGranted: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasAnalysisSelection) {
      unawaited(_checkPermission(continueIfGranted: true));
    }
  }

  Future<void> _checkPermission({bool continueIfGranted = false}) async {
    if (_isChecking || _hasNavigated || !_hasAnalysisSelection) return;

    setState(() => _isChecking = true);

    final status = await Permission.camera.status;
    if (!mounted) return;

    setState(() {
      _status = status;
      _isChecking = false;
    });

    if (continueIfGranted && status.isGranted) {
      _goToPreparation();
    }
  }

  Future<void> _requestPermission() async {
    if (_isBusy || _hasNavigated || !_hasAnalysisSelection) return;

    setState(() => _isChecking = true);

    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _status = status;
      _isChecking = false;
      _hasRequestedPermission = true;
    });

    if (status.isGranted) {
      _goToPreparation();
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  Future<void> _handlePrimaryAction() async {
    if (!_hasAnalysisSelection) {
      _goToExerciseSelection();
      return;
    }

    if (_isBlocked) {
      await _openSettings();
      return;
    }

    await _requestPermission();
  }

  void _goToPreparation() {
    if (_hasNavigated || !mounted || !_hasAnalysisSelection) return;

    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PreparationScreen()),
    );
  }

  void _goToExerciseSelection() {
    if (_hasNavigated || !mounted) return;

    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()),
    );
  }

  String _messageFor(AppLocalizations localizations) {
    final status = _status;

    if (status?.isRestricted == true) {
      return localizations.cameraPermissionRestrictedMessage;
    }

    if (status?.isPermanentlyDenied == true) {
      return localizations.cameraPermissionPermanentlyDeniedMessage;
    }

    if (status?.isDenied == true && _hasRequestedPermission) {
      return localizations.cameraPermissionDeniedMessage;
    }

    if (status?.isDenied == true) {
      return localizations.cameraPermissionPromptMessage;
    }

    return localizations.cameraPermissionRationale;
  }

  String _primaryLabelFor(AppLocalizations localizations) {
    final status = _status;

    if (_isBlocked) {
      return localizations.openSettings;
    }

    if (_isChecking) {
      return localizations.checking;
    }

    if (status?.isDenied == true && _hasRequestedPermission) {
      return localizations.retry;
    }

    return localizations.grantCameraPermission;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final selectedExercise = ref.watch(selectedExerciseProvider);
    final activeExercise = ref.watch(activeAnalysisExerciseProvider);

    if (selectedExercise == null || activeExercise == null) {
      return AppScaffoldShell(
        title: localizations.cameraPermission,
        showDrawer: false,
        padding: EdgeInsets.zero,
        body: AnalysisSelectionRequiredView(
          title: localizations.selectExerciseBeforeCameraTitle,
          message: localizations.selectExerciseBeforeCameraMessage,
          onSelectExercise: _goToExerciseSelection,
        ),
      );
    }

    return AppScaffoldShell(
      title: localizations.cameraPermission,
      showDrawer: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSurfaceCard(
                        variant: AppSurfaceVariant.strong,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PermissionHeader(
                              title: localizations.cameraPermissionRequired,
                              message: _messageFor(localizations),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _PermissionBenefit(
                              text: localizations.cameraDetectsJoints,
                            ),
                            _PermissionBenefit(
                              text: localizations.cameraEvaluatesForm,
                            ),
                            _PermissionBenefit(
                              text: localizations.cameraCountsReps,
                            ),
                            _PermissionBenefit(
                              text: localizations.cameraPrivacyNotice,
                            ),
                            _PermissionBenefit(
                              text: localizations.workoutDataStorageNotice,
                              icon: Icons.cloud_outlined,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: _primaryLabelFor(localizations),
                        onPressed: _isBusy ? null : _handlePrimaryAction,
                        icon: _isBlocked
                            ? Icons.settings_outlined
                            : Icons.camera_alt_outlined,
                        isLoading: _isBusy,
                        expand: true,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: localizations.back,
                        onPressed: () => Navigator.maybePop(context),
                        variant: AppButtonVariant.ghost,
                        expand: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PermissionHeader extends StatelessWidget {
  const _PermissionHeader({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.analysisAccent.withValues(alpha: AppOpacity.subtle),
            borderRadius: BorderRadius.circular(AppRadii.compact),
            border: Border.all(
              color: colors.analysisAccent.withValues(
                alpha: AppOpacity.strongBorder,
              ),
            ),
          ),
          child: Icon(
            Icons.photo_camera_outlined,
            color: colors.accent,
            size: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: textTheme.headlineMedium?.copyWith(
            color: colors.foreground,
            fontWeight: AppFontWeights.heavy,
            height: 1.12,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: textTheme.bodyLarge?.copyWith(
            color: colors.foregroundMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PermissionBenefit extends StatelessWidget {
  const _PermissionBenefit({
    required this.text,
    this.icon = Icons.check_circle_outline,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.accent, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.foreground,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
