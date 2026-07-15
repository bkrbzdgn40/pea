import 'models/analysis_frame.dart';

/// Common contract for engines that consume extracted analysis metrics.
///
/// This surface stays focused on lifecycle operations that are truly shared by
/// every engine family. Family-specific state, diagnostics, and feedback live
/// on typed engine surfaces.
abstract class AnalysisEngine {
  void update(AnalysisFrame frame);

  void reset();
}
