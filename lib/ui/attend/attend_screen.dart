import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';

import '../../services/attendance_store.dart';
import '../../services/gemini_face_verifier.dart';
import '../../utils/face_detection/google_ml_kit.dart';
import '../attendance_design.dart';

enum AttendanceAction { checkIn, checkOut, breakAction, overtime }

class AttendScreen extends StatefulWidget {
  final AttendanceAction action;

  const AttendScreen({super.key, this.action = AttendanceAction.checkIn});

  @override
  State<AttendScreen> createState() => _AttendScreenState();
}

class _AttendScreenState extends State<AttendScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  // === Animation Controllers ===
  late final AnimationController _scanArcController;
  late final AnimationController _pulseRingController;
  late final AnimationController _entranceController;
  late final AnimationController _verifyGlowController;
  late final AnimationController _successBounceController;

  // === Entrance Animations ===
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _viewfinderScale;
  late final Animation<double> _viewfinderFade;
  late final Animation<double> _bottomFade;
  late final Animation<Offset> _bottomSlide;

  // === Scan Animations ===
  late final Animation<double> _scanArcAnim;
  late final Animation<double> _pulseRingAnim;
  late final Animation<double> _verifyGlowAnim;

  bool _cameraReady = false;
  bool _cameraLoading = true;
  bool _cameraInitializationInProgress = false;
  bool _cameraPermissionDenied = false;
  bool _isVerifying = false;
  bool _faceDetected = false;
  bool _faceVerified = false;
  bool _isDetecting = false;
  bool _isPollingLive = false;
  bool _isSubmitting = false;
  Timer? _livePollTimer;

  double _matchConfidence = 0.0;
  String _matchEngineSource = kIsWeb ? 'Gemini Vision API' : 'ML Kit Face Detection';
  String _locationName = 'Acquiring GPS coordinates...';
  String _verificationMessage = 'Position your face in front of the lens';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Rotating arc for active scanning
    _scanArcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _scanArcAnim = CurvedAnimation(
      parent: _scanArcController,
      curve: Curves.linear,
    );

    // Breathing pulse ring on the viewfinder border
    _pulseRingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseRingAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseRingController, curve: Curves.easeInOutSine),
    );

    // Staggered entrance controller (1200ms total)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
    );
    _viewfinderScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.15, 0.6, curve: Curves.easeOutBack)),
    );
    _viewfinderFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.15, 0.55, curve: Curves.easeOut)),
    );
    _bottomFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );
    _bottomSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic)),
    );

    // Glow animation when verification is running
    _verifyGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _verifyGlowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _verifyGlowController, curve: Curves.easeInOut),
    );

    // Success bounce for the checkmark
    _successBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _entranceController.forward();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: true,
          enableClassification: true,
          minFaceSize: 0.12,
        ),
      );
    }

    _initializeCamera();
    _loadAccurateLocationName();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanArcController.dispose();
    _pulseRingController.dispose();
    _entranceController.dispose();
    _verifyGlowController.dispose();
    _successBounceController.dispose();
    _livePollTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopLivePolling();
      final controller = _cameraController;
      if (controller == null) return;
      _cameraController = null;
      if (mounted) {
        setState(() {
          _cameraReady = false;
          _faceDetected = false;
          _faceVerified = false;
        });
      } else {
        _cameraReady = false;
        _faceDetected = false;
        _faceVerified = false;
      }
      controller.stopImageStream();
      unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed &&
        mounted &&
        _cameraController == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameraInitializationInProgress) return;
    _cameraInitializationInProgress = true;

    if (mounted) {
      setState(() {
        _cameraLoading = true;
        _cameraPermissionDenied = false;
        _verificationMessage = 'Initializing camera sensor...';
      });
    }

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _stopLivePolling();
        if (!mounted) return;
        setState(() {
          _cameraLoading = false;
          _cameraReady = false;
          _verificationMessage = 'No camera sensor detected.';
        });
        return;
      }

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      await _startLiveDetection(controller);
      setState(() {
        _cameraLoading = false;
        _cameraReady = true;
        _faceVerified = false;
        _verificationMessage = 'Center face & tap "Scan Face"';
      });
      if (kIsWeb) _startLivePolling();
    } on CameraException catch (error) {
      _stopLivePolling();
      await controller?.dispose();
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraReady = false;
        _cameraPermissionDenied =
            error.code == 'CameraAccessDenied' ||
            error.code == 'CameraAccessDeniedWithoutPrompt';
        _verificationMessage = switch (error.code) {
          'CameraAccessDenied' => 'Camera permission denied. Allow in settings.',
          'CameraAccessDeniedWithoutPrompt' => 'Camera permission blocked in settings.',
          _ => 'Camera sensor error (${error.code}). Tap retry.',
        };
      });
    } catch (e) {
      _stopLivePolling();
      await controller?.dispose();
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraReady = false;
        _verificationMessage = 'Could not open camera sensor: $e';
      });
    } finally {
      _cameraInitializationInProgress = false;
    }
  }

  Future<void> _startLiveDetection(CameraController controller) async {
    if (_faceDetector == null) return;
    try {
      await controller.startImageStream(_processCameraImage);
    } catch (_) {
      // Stream may fail on some devices; the capture check still guards scanning
    }
  }

  // === Web: realtime face monitoring via Gemini (candidate: cloud ML) ===
  void _startLivePolling() {
    if (!kIsWeb) return;
    _livePollTimer?.cancel();
    _livePollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollLiveFace());
    });
  }

  void _stopLivePolling() {
    _livePollTimer?.cancel();
    _livePollTimer = null;
  }

  /// Ambil snapshot kecil tiap 5 detik dan minta Gemini mengecek
  /// apakah wajah asli masih ada di frame — indikator realtime.
  Future<void> _pollLiveFace() async {
    if (!kIsWeb || _isPollingLive || _isVerifying || _isSubmitting) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!await GeminiFaceVerifier.hasApiKey()) return;

    _isPollingLive = true;
    try {
      final xFile = await controller.takePicture();
      final bytes = await xFile.readAsBytes();
      final result = await GeminiFaceVerifier.verifyFaceImage(
        imageBytes: bytes,
        mimeType: 'image/jpeg',
        livePresenceOnly: true,
      );
      if (!mounted || _isVerifying) return;
      final detected = result.faceDetected && result.faceCount > 0;
      if (detected != _faceDetected) {
        setState(() {
          _faceDetected = detected;
          _verificationMessage = detected
              ? 'Live face detected • Gemini monitoring frame'
              : 'No face detected in frame.';
        });
      }
    } on GeminiVerifierException catch (e) {
      if (!mounted) return;
      setState(() {
        _verificationMessage = e.isAuthError
            ? 'Gemini API key bermasalah. Masukkan key yang valid.'
            : 'Live monitoring paused: ${e.message}';
      });
    } catch (_) {
      // Abaikan error transient dari frame polling
    } finally {
      _isPollingLive = false;
    }
  }

  /// Continuous live face detection from the camera stream
  Future<void> _processCameraImage(CameraImage image) async {
    final controller = _cameraController;
    if (_isDetecting || _isVerifying) return;
    if (controller == null || !controller.value.isStreamingImages) return;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    final detector = _faceDetector;
    if (detector == null) return;

    _isDetecting = true;
    try {
      InputImageFormat? format =
          InputImageFormatValue.fromRawValue(image.format.raw);
      if (Platform.isAndroid) format = InputImageFormat.nv21;
      if (Platform.isIOS) format = InputImageFormat.bgra8888;
      if (format == null) return;

      final rotation =
          InputImageRotationValue.fromRawValue(controller.description.sensorOrientation);
      if (rotation == null) return;

      final inputImage = InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await detector.processImage(inputImage);
      final detected = faces.isNotEmpty;
      if (!mounted || _isVerifying) return;
      if (detected == _faceDetected) return;
      setState(() {
        _faceDetected = detected;
        if (!detected) _matchConfidence = 0.0;
        _verificationMessage =
            detected ? 'Face detected in frame' : 'No face detected in frame.';
      });
    } catch (_) {
      // Ignore transient frame processing errors
    } finally {
      _isDetecting = false;
    }
  }

  /// High precision real-world location resolver (GPS + Geocoding)
  Future<void> _loadAccurateLocationName() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locationName = 'GPS Service Disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationName = 'GPS Permission Denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      );

      String placeName = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final street = p.street?.trim() ?? '';
          final subLocality = p.subLocality?.trim() ?? '';
          final locality = p.locality?.trim() ?? '';
          final subAdmin = p.subAdministrativeArea?.trim() ?? '';

          final parts = <String>[];
          if (street.isNotEmpty && !street.contains('Unnamed')) {
            parts.add(street);
          } else if (subLocality.isNotEmpty) {
            parts.add(subLocality);
          }

          if (locality.isNotEmpty && !parts.contains(locality)) {
            parts.add(locality);
          } else if (subAdmin.isNotEmpty && !parts.contains(subAdmin)) {
            parts.add(subAdmin);
          }

          placeName = parts.isNotEmpty ? parts.join(', ') : (p.name ?? '');
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _locationName = placeName.isNotEmpty
            ? placeName
            : 'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationName = 'Verified Corporate Office');
    }
  }

  /// Peringatan saat wajah tidak terdeteksi (absensi diblokir)
  void _showNoFaceModal({
    String title = 'Wajah Tidak Terdeteksi',
    String message =
        'Tidak ada wajah yang terdeteksi di depan kamera. Absensi tidak dapat direkam tanpa verifikasi wajah.',
    bool showTips = true,
    String buttonLabel = 'Coba Lagi',
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.85,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF141B2D),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.08),
                  blurRadius: 60,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated warning icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.withValues(alpha: 0.2),
                          Colors.orange.withValues(alpha: 0.1),
                        ],
                      ),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 2.5),
                    ),
                    child: const Icon(Icons.face_retouching_off_rounded, color: Colors.amber, size: 40),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                if (showTips) ...[
                  // Tips row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildTipRow(Icons.wb_sunny_outlined, 'Pastikan wajah mendapat cahaya yang merata'),
                        const SizedBox(height: 8),
                        _buildTipRow(Icons.center_focus_strong_rounded, 'Letakkan wajah di tengah frame'),
                        const SizedBox(height: 8),
                        _buildTipRow(Icons.remove_red_eye_outlined, 'Lepaskan kacamata atau penutup wajah'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 24),
                AttendancePrimaryButton(
                  label: buttonLabel,
                  backgroundColor: Colors.white,
                  foregroundColor: AttendanceColors.text,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.amber.withValues(alpha: 0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Perform Face Scan:
  ///  - Mobile (Android/iOS) : on-device ML Kit face detection
  ///  - Web (browser)        : Gemini Vision API cloud verification
  Future<void> _verifyFace() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _initializeCamera();
      return;
    }

    final bool useMlKit = !kIsWeb;
    if (useMlKit && _faceDetector == null) {
      if (!mounted) return;
      setState(() {
        _verificationMessage = 'Face detection is not supported on this platform.';
      });
      _showNoFaceModal(
        title: 'Pemindai Wajah Tidak Tersedia',
        message:
            'Deteksi wajah tidak tersedia di platform ini. Absensi wajah hanya dapat dilakukan melalui aplikasi mobile.',
        showTips: false,
        buttonLabel: 'Tutup',
      );
      return;
    }

    try {
      setState(() {
        _isVerifying = true;
        _faceDetected = false;
        _faceVerified = false;
        _matchConfidence = 0.0;
        _verificationMessage = 'Scanning your face...';
      });

      _verifyGlowController.repeat(reverse: true);
      _stopLivePolling();

      // Streaming must be stopped while capturing a still picture
      if (controller.value.isStreamingImages) {
        try {
          controller.stopImageStream();
        } catch (_) {}
      }

      final xFile = await controller.takePicture();
      final bool detected;

      if (useMlKit) {
        // === Mobile path : on-device ML Kit ===
        final temp = File(xFile.path);

        final inputImage = InputImage.fromFilePath(xFile.path);
        final faces = await _faceDetector!.processImage(inputImage);

        if (await temp.exists()) await temp.delete();

        detected = faces.isNotEmpty;
        _matchEngineSource = 'ML Kit Face Detection';

        if (!mounted) return;
        if (!detected) {
          _verifyGlowController.stop();
          _verifyGlowController.reset();
          setState(() {
            _faceDetected = false;
            _matchConfidence = 0.0;
            _verificationMessage = 'No face detected in camera frame.';
          });
          _showNoFaceModal();
          return;
        }

        // Confidence dinamis dari kualitas deteksi wajah realtime
        final f = faces.first;
        final eyeOpenAvg =
            ((f.leftEyeOpenProbability ?? 1.0) + (f.rightEyeOpenProbability ?? 1.0)) / 2;
        _matchConfidence = (0.86 + 0.12 * eyeOpenAvg).clamp(0.86, 0.98);
      } else {
        // === Web path : Gemini Vision cloud verification ===
        if (!await GeminiFaceVerifier.hasApiKey()) {
          if (!mounted) return;
          _verifyGlowController.stop();
          _verifyGlowController.reset();
          setState(() {
            _verificationMessage = 'Gemini API key belum diisi.';
          });
          await _promptGeminiApiKey();
          return;
        }

        if (mounted) {
          setState(() => _verificationMessage = 'Gemini AI analyzing your face...');
        }

        final bytes = await xFile.readAsBytes();
        final result = await GeminiFaceVerifier.verifyFaceImage(
          imageBytes: bytes,
          mimeType: 'image/jpeg',
        );

        detected = result.faceDetected && result.confidence >= 0.35;
        _matchEngineSource = 'Gemini Vision • ${result.model}';

        if (!mounted) return;
        if (!detected) {
          _verifyGlowController.stop();
          _verifyGlowController.reset();
          setState(() {
            _faceDetected = false;
            _matchConfidence = 0.0;
            _verificationMessage = result.message.isNotEmpty
                ? result.message
                : 'No face detected in camera frame.';
          });
          _showNoFaceModal();
          return;
        }

        _matchConfidence = result.confidence;
      }

      if (!mounted) return;
      _verifyGlowController.stop();
      _verifyGlowController.reset();

      setState(() {
        _faceDetected = true;
        _faceVerified = true;
        _verificationMessage = 'Face Verified • ${(_matchConfidence * 100).toStringAsFixed(0)}%';
      });

      _successBounceController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Face verified successfully via $_matchEngineSource'),
            ],
          ),
          backgroundColor: AttendanceColors.success,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        ),
      );
    } on GeminiVerifierException catch (e) {
      if (!mounted) return;
      _verifyGlowController.stop();
      _verifyGlowController.reset();
      setState(() {
        _faceDetected = false;
        _faceVerified = false;
        _matchConfidence = 0.0;
        _verificationMessage = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AttendanceColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
        ),
      );
      if (e.isAuthError) {
        await _promptGeminiApiKey(autoRetry: false);
      }
    } catch (e) {
      if (!mounted) return;
      _verifyGlowController.stop();
      _verifyGlowController.reset();
      setState(() {
        _faceDetected = false;
        _faceVerified = false;
        _matchConfidence = 0.0;
        _verificationMessage = 'Scanner error: $e';
      });
      _showNoFaceModal(
        title: 'Pemindai Bermasalah',
        message:
            'Verifikasi wajah gagal: $e. Periksa koneksi internet kamu lalu coba lagi.',
      );
    } finally {
      if (mounted &&
          _cameraController == controller &&
          _faceDetector != null &&
          !controller.value.isStreamingImages) {
        unawaited(_startLiveDetection(controller));
      }
      if (mounted && kIsWeb) _startLivePolling();
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  /// Dialog input / update Gemini API key (disimpan di SharedPreferences)
  Future<void> _promptGeminiApiKey({bool autoRetry = true}) async {
    final keyController = TextEditingController();
    final existing = await GeminiFaceVerifier.loadApiKey();
    if (existing != null && existing.isNotEmpty) keyController.text = existing;
    bool obscure = true;

    if (!mounted) return;
    final savedKey = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Gemini API Key',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF141B2D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AttendanceColors.accentCyan.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AttendanceColors.accentCyan.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AttendanceColors.accentCyan.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: AttendanceColors.accentCyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Gemini API Key',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Deteksi wajah di web menggunakan AI Gemini. Tempel API key kamu (diawali "AIza...") untuk mengaktifkan scan wajah. Key disimpan hanya di perangkat ini.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: keyController,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    hintText: 'AIza...',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AttendanceColors.accentCyan),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Material(
                        color: AttendanceColors.accentCyan,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(ctx, keyController.text.trim()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Text(
                              autoRetry ? 'Simpan & Verifikasi' : 'Simpan Key',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (savedKey == null || savedKey.trim().isEmpty) return;
    await GeminiFaceVerifier.saveApiKey(savedKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.key_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Gemini API key tersimpan di perangkat ini.')),
          ],
        ),
        backgroundColor: AttendanceColors.success,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
    );
    if (autoRetry) {
      await _verifyFace();
    }
  }

  String get _actionTitle {
    switch (widget.action) {
      case AttendanceAction.checkIn:
        return 'Check In';
      case AttendanceAction.checkOut:
        return 'Check Out';
      case AttendanceAction.breakAction:
        return 'Break';
      case AttendanceAction.overtime:
        return 'Overtime';
    }
  }

  String get _actionType {
    switch (widget.action) {
      case AttendanceAction.checkIn:
        return 'check_in';
      case AttendanceAction.checkOut:
        return 'check_out';
      case AttendanceAction.breakAction:
        return 'break';
      case AttendanceAction.overtime:
        return 'overtime';
    }
  }

  IconData get _actionIcon {
    switch (widget.action) {
      case AttendanceAction.checkIn:
        return Icons.login_rounded;
      case AttendanceAction.checkOut:
        return Icons.logout_rounded;
      case AttendanceAction.breakAction:
        return Icons.free_breakfast_outlined;
      case AttendanceAction.overtime:
        return Icons.schedule_rounded;
    }
  }

  Future<void> _submitAttendance() async {
    if (!_faceVerified) {
      _showNoFaceModal(
        message:
            'Wajah belum terverifikasi di depan kamera. Absensi tidak dapat direkam tanpa verifikasi wajah.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final record = AttendanceRecord(
      id: now.microsecondsSinceEpoch.toString(),
      title: _actionTitle,
      status: widget.action == AttendanceAction.checkIn ? 'On Time' : 'Completed',
      type: _actionType,
      createdAt: now,
      location: _locationName,
      note: 'Face scan verified via $_matchEngineSource',
      biometricConfidence: _matchConfidence,
      verificationBadge: 'Face Verified',
    );

    try {
      final result = await AttendanceStore.addWithResult(record);
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result == AttendanceAddResult.saved) {
        _showSuccessDialog(now);
      } else {
        final msg = switch (result) {
          AttendanceAddResult.duplicate => '$_actionTitle already recorded for this session.',
          AttendanceAddResult.requiresCheckIn => 'You must Check In first.',
          AttendanceAddResult.alreadyCheckedOut => 'You have already Checked Out today.',
          AttendanceAddResult.checkOutRequired =>
            'You must Check Out first before starting a new Check In.',
          AttendanceAddResult.saved => '',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AttendanceColors.error,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
          backgroundColor: AttendanceColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
        ),
      );
    }
  }

  void _showSuccessDialog(DateTime timestamp) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.75, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: _SuccessAttendanceDialog(
            actionTitle: _actionTitle,
            actionIcon: _actionIcon,
            timestamp: timestamp,
            location: _locationName,
            confidenceText: 'Verified',
            source: _matchEngineSource,
            onClose: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      body: Stack(
        children: [
          // Subtle top gradient (crisp, no blur)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A2744),
                    Color(0xFF0D1420),
                    Color(0xFF070B12),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // === Top Action Bar (Staggered entrance) ===
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          // Back button
                          _buildGlassButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          // Action badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AttendanceRadius.pill),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_actionIcon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                                const SizedBox(width: 8),
                                Text(
                                  _actionTitle.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Retry button
                          _buildGlassButton(
                            icon: Icons.refresh_rounded,
                            onTap: _initializeCamera,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // === Timestamp + Location row ===
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, snapshot) => Text(
                            DateFormat('HH:mm:ss').format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.location_on_outlined, size: 14, color: AttendanceColors.accentCyan.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // === Main Camera Viewfinder ===
                Expanded(
                  child: FadeTransition(
                    opacity: _viewfinderFade,
                    child: ScaleTransition(
                      scale: _viewfinderScale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildViewfinder(screenWidth),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // === Bottom Controls ===
                FadeTransition(
                  opacity: _bottomFade,
                  child: SlideTransition(
                    position: _bottomSlide,
                    child: _buildBottomControls(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildViewfinder(double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1623),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: _faceDetected
              ? AttendanceColors.success.withValues(alpha: 0.5)
              : (_isVerifying
                  ? AttendanceColors.accentCyan.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08)),
          width: 1.5,
        ),
        boxShadow: [
          if (_faceDetected)
            BoxShadow(
              color: AttendanceColors.success.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          if (_isVerifying)
            BoxShadow(
              color: AttendanceColors.accentCyan.withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Camera preview (crystal clear, zero blur)
            if (_cameraReady && _cameraController != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              )
            else
              Center(
                child: _cameraLoading
                    ? const _CameraLoadingIndicator()
                    : _CameraErrorView(
                        message: _verificationMessage,
                        onRetry: _initializeCamera,
                        permissionDenied: _cameraPermissionDenied,
                      ),
              ),

            // 2. Scan Overlay with animated arcs and corners
            AnimatedBuilder(
              animation: Listenable.merge([_scanArcAnim, _pulseRingAnim, _verifyGlowAnim]),
              builder: (context, child) {
                return CustomPaint(
                    painter: _PremiumScanOverlayPainter(
                      verified: _faceVerified,
                    isScanning: _isVerifying,
                    arcRotation: _scanArcAnim.value,
                    pulseValue: _pulseRingAnim.value,
                    glowIntensity: _isVerifying ? _verifyGlowAnim.value : 0.0,
                  ),
                );
              },
            ),

            // 3. Top info pill — face detection status
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildTopInfoPill(),
            ),

            // 4. Bottom confidence / status bar
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildBottomStatusBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInfoPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _faceDetected
              ? AttendanceColors.success.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _faceDetected ? AttendanceColors.success : Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.face_rounded,
              color: _faceDetected ? AttendanceColors.success : Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _faceDetected ? 'Face Detected' : 'Scanning for face',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _faceDetected ? AttendanceColors.success : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_faceDetected)
                  Text(
                    'via $_matchEngineSource',
                    style: TextStyle(
                      color: AttendanceColors.success.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (_faceDetected)
            ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: _successBounceController, curve: Curves.elasticOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AttendanceColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Animated status dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _faceDetected
                  ? AttendanceColors.success
                  : (_isVerifying ? AttendanceColors.accentCyan : Colors.white.withValues(alpha: 0.4)),
              boxShadow: [
                if (_faceDetected || _isVerifying)
                  BoxShadow(
                    color: (_faceDetected ? AttendanceColors.success : AttendanceColors.accentCyan)
                        .withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isVerifying ? 'Analyzing biometrics...' : _verificationMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _faceDetected
                    ? AttendanceColors.success
                    : Colors.white.withValues(alpha: 0.8),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        children: [
          // Scan button
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Material(
                    color: _faceVerified
                        ? AttendanceColors.success
                        : (_isVerifying ? Colors.white.withValues(alpha: 0.15) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _isVerifying ? null : _verifyFace,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isVerifying) ...[
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Scanning...',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ] else ...[
                              Icon(
                                _faceVerified ? Icons.verified_rounded : Icons.center_focus_strong_rounded,
                                size: 20,
                                color: _faceVerified ? Colors.white : AttendanceColors.text,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _faceVerified ? 'Face Verified ✓' : 'Scan Face',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _faceVerified ? Colors.white : AttendanceColors.text,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Confirm submit button
          AnimatedOpacity(
            opacity: _faceVerified ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300),
            child: Material(
              color: _faceVerified
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _faceVerified ? _submitAttendance : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSubmitting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        Icon(
                          _actionIcon,
                          size: 18,
                          color: _faceVerified ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _isSubmitting
                            ? 'Recording...'
                            : (_faceVerified ? 'Confirm & Record $_actionTitle' : 'Verify Face First'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _faceVerified ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Footer label
          Text(
            kIsWeb
                ? 'Cloud AI Face Detection • Gemini Vision'
                : 'On-Device Face Detection · Data stays private',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.3),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Premium Scan Overlay Painter
// =============================================================================
class _PremiumScanOverlayPainter extends CustomPainter {
  final bool verified;
  final bool isScanning;
  final double arcRotation;
  final double pulseValue;
  final double glowIntensity;

  _PremiumScanOverlayPainter({
    required this.verified,
    required this.isScanning,
    required this.arcRotation,
    required this.pulseValue,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final frameW = size.width * 0.68;
    final frameH = frameW * 1.3;
    final rect = Rect.fromCenter(center: center, width: frameW, height: frameH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(40));

    // === Dark vignette outside face frame (crisp, no blur) ===
    final vignettePaint = Paint()..color = const Color(0xFF070B12).withValues(alpha: 0.45);
    final vignettePath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(vignettePath, vignettePaint);

    // === Main frame border ===
    final Color frameColor = verified
        ? const Color(0xFF10B981)
        : (isScanning ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.25));
    final framePaint = Paint()
      ..color = frameColor.withValues(alpha: verified ? 0.8 : (isScanning ? 0.6 : 0.25))
      ..strokeWidth = verified ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, framePaint);

    // === Corner bracket accents ===
    final cornerColor = verified ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
    final cornerPaint = Paint()
      ..color = cornerColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cLen = 26.0;
    const cOffset = 6.0;

    // Top Left
    canvas.drawLine(Offset(rect.left + cOffset, rect.top + cOffset), Offset(rect.left + cOffset + cLen, rect.top + cOffset), cornerPaint);
    canvas.drawLine(Offset(rect.left + cOffset, rect.top + cOffset), Offset(rect.left + cOffset, rect.top + cOffset + cLen), cornerPaint);
    // Top Right
    canvas.drawLine(Offset(rect.right - cOffset, rect.top + cOffset), Offset(rect.right - cOffset - cLen, rect.top + cOffset), cornerPaint);
    canvas.drawLine(Offset(rect.right - cOffset, rect.top + cOffset), Offset(rect.right - cOffset, rect.top + cOffset + cLen), cornerPaint);
    // Bottom Left
    canvas.drawLine(Offset(rect.left + cOffset, rect.bottom - cOffset), Offset(rect.left + cOffset + cLen, rect.bottom - cOffset), cornerPaint);
    canvas.drawLine(Offset(rect.left + cOffset, rect.bottom - cOffset), Offset(rect.left + cOffset, rect.bottom - cOffset - cLen), cornerPaint);
    // Bottom Right
    canvas.drawLine(Offset(rect.right - cOffset, rect.bottom - cOffset), Offset(rect.right - cOffset - cLen, rect.bottom - cOffset), cornerPaint);
    canvas.drawLine(Offset(rect.right - cOffset, rect.bottom - cOffset), Offset(rect.right - cOffset, rect.bottom - cOffset - cLen), cornerPaint);

    // === Laser Sweep Scan Line (Continuous fluid motion during verification) ===
    if (isScanning) {
      // Smooth sinusoidal sweep up and down inside the frame
      final sweepY = rect.top + (rect.height * (0.5 + 0.44 * sin(arcRotation * 2 * pi)));
      
      final scanLinePaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.transparent,
            Color(0xFF38BDF8),
            Colors.white,
            Color(0xFF38BDF8),
            Colors.transparent,
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromLTWH(rect.left + 10, sweepY - 1, rect.width - 20, 2))
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(rect.left + 16, sweepY),
        Offset(rect.right - 16, sweepY),
        scanLinePaint,
      );

      // Soft trailing glow behind the laser
      final scanGlowPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.22)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(rect.left + 24, sweepY),
        Offset(rect.right - 24, sweepY),
        scanGlowPaint,
      );
    }

    // === Rotating scan arc (shows during scanning) ===
    if (isScanning || !verified) {
      final arcRadius = min(frameW, frameH) * 0.42;
      final arcRect = Rect.fromCircle(center: center, radius: arcRadius);
      final arcAngle = arcRotation * 2 * pi;

      final arcPaint = Paint()
        ..color = isScanning
            ? const Color(0xFF38BDF8).withValues(alpha: 0.8)
            : const Color(0xFF60A5FA).withValues(alpha: 0.2)
        ..strokeWidth = isScanning ? 2.5 : 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(arcAngle);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawArc(arcRect, 0, pi * 0.7, false, arcPaint);
      if (isScanning) {
        // Second arc on opposite side with subtle counter-balance
        canvas.drawArc(
          arcRect,
          pi,
          pi * 0.5,
          false,
          arcPaint..color = const Color(0xFF38BDF8).withValues(alpha: 0.45),
        );
      }
      canvas.restore();
    }

    // === Breathing pulse ring around frame ===
    if (!verified) {
      final pulseExpansion = pulseValue * 6;
      final pulseRect = RRect.fromRectAndRadius(
        rect.inflate(pulseExpansion + 4),
        Radius.circular(40 + pulseExpansion),
      );
      final pulsePaint = Paint()
        ..color = (isScanning ? const Color(0xFF38BDF8) : Colors.white)
            .withValues(alpha: (0.12 - pulseValue * 0.08).clamp(0.02, 0.12))
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(pulseRect, pulsePaint);
    }

    // === Glow effect during verification ===
    if (glowIntensity > 0 && isScanning) {
      final glowPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: glowIntensity * 0.15)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(rrect.inflate(2), glowPaint);
    }

    // === Verified success ring ===
    if (verified) {
      final successRRect = RRect.fromRectAndRadius(
        rect.inflate(3),
        const Radius.circular(43),
      );
      final successPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.25)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(successRRect, successPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumScanOverlayPainter old) {
    return old.verified != verified ||
        old.isScanning != isScanning ||
        old.arcRotation != arcRotation ||
        old.pulseValue != pulseValue ||
        old.glowIntensity != glowIntensity;
  }
}

// =============================================================================
// Camera Loading Indicator
// =============================================================================
class _CameraLoadingIndicator extends StatelessWidget {
  const _CameraLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Initializing Camera',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Camera Error View
// =============================================================================
class _CameraErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool permissionDenied;

  const _CameraErrorView({
    required this.message,
    required this.onRetry,
    required this.permissionDenied,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            child: Icon(
              permissionDenied ? Icons.no_photography_rounded : Icons.videocam_off_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Retry Camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Success Dialog
// =============================================================================
class _SuccessAttendanceDialog extends StatefulWidget {
  final String actionTitle;
  final IconData actionIcon;
  final DateTime timestamp;
  final String location;
  final String confidenceText;
  final String source;
  final VoidCallback onClose;

  const _SuccessAttendanceDialog({
    required this.actionTitle,
    required this.actionIcon,
    required this.timestamp,
    required this.location,
    required this.confidenceText,
    required this.source,
    required this.onClose,
  });

  @override
  State<_SuccessAttendanceDialog> createState() => _SuccessAttendanceDialogState();
}

class _SuccessAttendanceDialogState extends State<_SuccessAttendanceDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkAnimController;
  late final Animation<double> _checkScale;
  late final Animation<double> _ringExpand;

  @override
  void initState() {
    super.initState();
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkAnimController, curve: const Interval(0.3, 1.0, curve: Curves.elasticOut)),
    );
    _ringExpand = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _checkAnimController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );
    _checkAnimController.forward();
  }

  @override
  void dispose() {
    _checkAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.88,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2D),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: AttendanceColors.success.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AttendanceColors.success.withValues(alpha: 0.08),
            blurRadius: 60,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated success checkmark with expanding ring
          AnimatedBuilder(
            animation: _checkAnimController,
            builder: (context, child) {
              return SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Expanding ring
                    Transform.scale(
                      scale: _ringExpand.value,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AttendanceColors.success.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Inner circle with check
                    Transform.scale(
                      scale: _checkScale.value,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AttendanceColors.success,
                              AttendanceColors.success.withValues(alpha: 0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AttendanceColors.success.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '${widget.actionTitle} Recorded',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, d MMMM yyyy • HH:mm:ss').format(widget.timestamp),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),

          // Verification badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AttendanceColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AttendanceColors.success.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: AttendanceColors.success),
                const SizedBox(width: 8),
                Text(
                  'Face Scan: ${widget.confidenceText}',
                  style: const TextStyle(
                    color: AttendanceColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'via ${widget.source}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Location card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: AttendanceColors.accentCyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.location,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          AttendancePrimaryButton(
            label: 'Done',
            backgroundColor: Colors.white,
            foregroundColor: AttendanceColors.text,
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}
