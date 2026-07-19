enum CameraView { side, front }

enum CameraViewSupport { preferred, supported, unsupported }

class CameraViewContract {
  CameraViewContract({required Map<CameraView, CameraViewSupport> views})
    : views = Map<CameraView, CameraViewSupport>.unmodifiable(
        <CameraView, CameraViewSupport>{
          for (final view in CameraView.values)
            if (views.containsKey(view)) view: views[view]!,
        },
      ) {
    final missingViews = CameraView.values.where(
      (view) => !this.views.containsKey(view),
    );
    if (missingViews.isNotEmpty) {
      throw ArgumentError.value(
        missingViews.toSet(),
        'views',
        'Every camera view must declare a support status.',
      );
    }
  }

  final Map<CameraView, CameraViewSupport> views;

  CameraViewSupport supportFor(CameraView view) => views[view]!;

  Set<CameraView> get preferredViews =>
      _viewsWhere((support) => support == CameraViewSupport.preferred);

  Set<CameraView> get supportedViews =>
      _viewsWhere((support) => support != CameraViewSupport.unsupported);

  Set<CameraView> get unsupportedViews =>
      _viewsWhere((support) => support == CameraViewSupport.unsupported);

  Set<CameraView> _viewsWhere(
    bool Function(CameraViewSupport support) predicate,
  ) {
    return Set<CameraView>.unmodifiable(
      CameraView.values.where((view) => predicate(supportFor(view))),
    );
  }
}
