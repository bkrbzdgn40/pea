import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';

void main() {
  test('camera-view enums contain exactly the roadmap values in order', () {
    expect(CameraView.values, <CameraView>[CameraView.side, CameraView.front]);
    expect(CameraViewSupport.values, <CameraViewSupport>[
      CameraViewSupport.preferred,
      CameraViewSupport.supported,
      CameraViewSupport.unsupported,
    ]);
  });

  test('reports explicit status and operationally supported views', () {
    final contract = CameraViewContract(
      views: const <CameraView, CameraViewSupport>{
        CameraView.side: CameraViewSupport.supported,
        CameraView.front: CameraViewSupport.preferred,
      },
    );

    expect(contract.supportFor(CameraView.side), CameraViewSupport.supported);
    expect(contract.supportFor(CameraView.front), CameraViewSupport.preferred);
    expect(contract.preferredViews, <CameraView>{CameraView.front});
    expect(contract.supportedViews.toList(), <CameraView>[
      CameraView.side,
      CameraView.front,
    ]);
    expect(contract.unsupportedViews, isEmpty);
  });

  test('excludes unsupported views from operational support', () {
    final contract = CameraViewContract(
      views: const <CameraView, CameraViewSupport>{
        CameraView.side: CameraViewSupport.preferred,
        CameraView.front: CameraViewSupport.unsupported,
      },
    );

    expect(contract.preferredViews, <CameraView>{CameraView.side});
    expect(contract.supportedViews, <CameraView>{CameraView.side});
    expect(contract.unsupportedViews, <CameraView>{CameraView.front});
  });

  test('copies and protects stored metadata and query results', () {
    final source = <CameraView, CameraViewSupport>{
      CameraView.side: CameraViewSupport.preferred,
      CameraView.front: CameraViewSupport.unsupported,
    };
    final contract = CameraViewContract(views: source);

    source[CameraView.side] = CameraViewSupport.unsupported;

    expect(contract.supportFor(CameraView.side), CameraViewSupport.preferred);
    expect(
      () => contract.views[CameraView.side] = CameraViewSupport.supported,
      throwsUnsupportedError,
    );
    expect(
      () => contract.supportedViews.add(CameraView.front),
      throwsUnsupportedError,
    );
  });

  test('rejects missing camera-view declarations', () {
    expect(
      () => CameraViewContract(
        views: const <CameraView, CameraViewSupport>{
          CameraView.side: CameraViewSupport.preferred,
        },
      ),
      throwsArgumentError,
    );
  });
}
