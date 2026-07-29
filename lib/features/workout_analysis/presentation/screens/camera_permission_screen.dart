import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/localization/app_localizations.dart';

import '../providers/active_analysis_exercise_provider.dart';
import '../providers/selected_exercise_provider.dart';
import '../widgets/analysis_selection_required_view.dart';
import 'preparation_screen.dart';
import 'exercise_selection_screen.dart';

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
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(localizations.cameraPermission),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: AnalysisSelectionRequiredView(
          title: localizations.selectExerciseBeforeCameraTitle,
          message: localizations.selectExerciseBeforeCameraMessage,
          onSelectExercise: _goToExerciseSelection,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(localizations.cameraPermission),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.greenAccent,
                      size: 42,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      localizations.cameraPermissionRequired,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _messageFor(localizations),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PermissionBenefit(text: localizations.cameraDetectsJoints),
                    _PermissionBenefit(text: localizations.cameraEvaluatesForm),
                    _PermissionBenefit(text: localizations.cameraCountsReps),
                    _PermissionBenefit(text: localizations.cameraPrivacyNotice),
                    _PermissionBenefit(
                      text: localizations.workoutDataStorageNotice,
                      icon: Icons.cloud_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _isBusy ? null : _handlePrimaryAction,
                icon: _isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isBlocked
                            ? Icons.settings_outlined
                            : Icons.camera_alt_outlined,
                      ),
                label: Text(_primaryLabelFor(localizations)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white24,
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizations.back),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
