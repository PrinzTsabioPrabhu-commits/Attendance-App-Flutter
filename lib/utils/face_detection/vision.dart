import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class Vision {
  Vision._();
  static final Vision instance = Vision._();

  FaceDetector faceDetector([FaceDetectorOptions? options]) {
    return FaceDetector(
      options:
          options ??
          FaceDetectorOptions(
            enableClassification: false,
            enableLandmarks: false,
            performanceMode: FaceDetectorMode.fast,
            minFaceSize: 0.08,
          ),
    );
  }
}
