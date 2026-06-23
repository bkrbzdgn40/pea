import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/camera_provider.dart';
import '../providers/workout_controller.dart';
import '../widgets/pose_painter.dart';

class LiveAnalysisScreen extends ConsumerWidget {
  const LiveAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraProvider);
    final workoutState = ref.watch(workoutControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraState.when(
        data: (controller) {
          if (!controller.value.isStreamingImages) {
            controller.startImageStream((image) {
              ref.read(workoutControllerProvider.notifier).processCameraImage(
                    image,
                    controller.description.sensorOrientation,
                  );
            });
          }

          final imageSize = Size(
            controller.value.previewSize!.height,
            controller.value.previewSize!.width,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              
              // İskelet Çizimi (Form hatasına göre renk değiştirir)
              if (workoutState.landmarks != null && workoutState.landmarks!.isNotEmpty)
                CustomPaint(
                  painter: PosePainter(
                    workoutState.landmarks!, 
                    imageSize,
                    isFormBad: workoutState.isFormBad,
                  ),
                ),

              // Üst Panel: Tekrar ve Puan
              Positioned(
                top: 60,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricCard(label: "TEKRAR", value: "${workoutState.repCount}"),
                    _MetricCard(
                      label: "FPS",
                      value: workoutState.cameraFps.toStringAsFixed(0),
                      color: Colors.cyanAccent,
                    ),
                    _MetricCard(
                      label: "SKOR", 
                      value: workoutState.lastRepScore.toInt().toString(),
                      color: Colors.greenAccent,
                    ),
                  ],
                ),
              ),

              // Alt Panel: Feedback ve Faz
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: workoutState.isFormBad ? Colors.red.withOpacity(0.8) : Colors.black54,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: workoutState.isFormBad ? Colors.white : Colors.greenAccent),
                      ),
                      child: Text(
                        workoutState.feedbackMessage.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "DURUM: ${workoutState.currentPhase} | ANALİZ FPS: ${workoutState.analysisFps.toStringAsFixed(0)}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Hata: $error')),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: color, 
              fontSize: 32, 
              fontWeight: FontWeight.w900, // FontWeight.black yerine w900 kullanıldı
            ),
          ),
        ],
      ),
    );
  }
}
