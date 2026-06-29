import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'calibration_screen.dart';

class CameraPermissionScreen extends StatefulWidget {
  const CameraPermissionScreen({super.key});

  @override
  State<CameraPermissionScreen> createState() => _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends State<CameraPermissionScreen>
    with WidgetsBindingObserver {
  PermissionStatus? _status;
  bool _isChecking = false;
  bool _hasNavigated = false;

  bool get _isBlocked {
    final status = _status;
    return status?.isPermanentlyDenied == true || status?.isRestricted == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkPermission(continueIfGranted: true));
    }
  }

  Future<void> _checkPermission({bool continueIfGranted = false}) async {
    if (_isChecking || _hasNavigated) return;

    setState(() => _isChecking = true);

    final status = await Permission.camera.status;
    if (!mounted) return;

    setState(() {
      _status = status;
      _isChecking = false;
    });

    if (continueIfGranted && status.isGranted) {
      _goToCalibration();
    }
  }

  Future<void> _requestPermission() async {
    if (_isChecking || _hasNavigated) return;

    setState(() => _isChecking = true);

    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _status = status;
      _isChecking = false;
    });

    if (status.isGranted) {
      _goToCalibration();
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  Future<void> _handlePrimaryAction() async {
    if (_isBlocked) {
      await _openSettings();
      return;
    }

    await _requestPermission();
  }

  void _goToCalibration() {
    if (_hasNavigated || !mounted) return;

    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );
  }

  String get _message {
    final status = _status;

    if (status?.isRestricted == true) {
      return 'Bu cihazda kamera izni kısıtlanmış görünüyor. Devam etmek için cihaz ayarlarını kontrol et.';
    }

    if (status?.isPermanentlyDenied == true) {
      return 'Kamera izni kalıcı olarak kapalı. Analize devam etmek için telefon ayarlarından kamera iznini açman gerekiyor.';
    }

    if (status?.isDenied == true) {
      return 'Kamera izni verilmedi. Vücut eklemlerini algılamak ve hareket formunu analiz etmek için izne ihtiyacımız var.';
    }

    return 'Vücut eklemlerini algılamak, hareket formunu analiz etmek ve tekrarları gerçek zamanlı saymak için kamera izni gerekiyor.';
  }

  String get _primaryLabel {
    if (_isBlocked) {
      return 'Ayarları Aç';
    }

    if (_isChecking) {
      return 'Kontrol Ediliyor';
    }

    return 'Kamera İzni Ver';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Kamera İzni'),
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
                    const Text(
                      'Kamera İzni Gerekli',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _PermissionBenefit(
                      text: 'Vücut eklemlerini algılar.',
                    ),
                    const _PermissionBenefit(
                      text: 'Hareket formunu gerçek zamanlı değerlendirir.',
                    ),
                    const _PermissionBenefit(
                      text: 'Doğru tekrarları saymaya yardımcı olur.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _handlePrimaryAction,
                icon: _isChecking
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
                label: Text(_primaryLabel),
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
                child: const Text('Geri Dön'),
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
  const _PermissionBenefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 20,
          ),
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
