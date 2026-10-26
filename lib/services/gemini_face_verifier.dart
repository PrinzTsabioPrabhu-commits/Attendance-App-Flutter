import 'dart:convert';

import 'package:attendance_app/config/secrets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Hasil verifikasi wajah dari Gemini Vision API
class GeminiFaceResult {
  final bool faceDetected;
  final int faceCount;
  final double confidence;
  final String message;
  final String model;

  const GeminiFaceResult({
    required this.faceDetected,
    required this.faceCount,
    required this.confidence,
    required this.message,
    required this.model,
  });
}

/// Exception bawaan service Gemini agar UI bisa menampilkan pesan yang tepat
class GeminiVerifierException implements Exception {
  final String message;
  final bool isAuthError;

  const GeminiVerifierException(this.message, {this.isAuthError = false});

  @override
  String toString() => message;
}

/// Verifikasi wajah via Google Gemini (REST generativelanguage).
///
/// Dipakai sebagai face-detection engine di platform web karena
/// Google ML Kit tidak mendukung Flutter Web. API key diinput
/// pengguna dari dalam aplikasi dan disimpan via SharedPreferences,
/// sehingga tidak ada key yang di-hardcode di source.
class GeminiFaceVerifier {
  GeminiFaceVerifier._();

  static const _keyPref = 'gemini_api_key_v1';

  /// API key default dibaca dari lib/config/secrets.dart (git-ignored).
  /// Bisa ditimpa lewat dialog input key di aplikasi (SharedPreferences).
  static String get defaultApiKey => Secrets.geminiApiKey;

  /// Model fallback berurutan — model vision terbaru ditagih dulu.
  static const _modelChain = <String>[
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  /// API key aktif (runtime): key yang diinput pengguna via UI,
  /// atau fallback ke [defaultApiKey].
  static Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref)?.trim();
    if (key != null && key.isNotEmpty) return key;
    return defaultApiKey;
  }

  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, apiKey.trim());
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPref);
  }

  static Future<bool> hasApiKey() async {
    final key = await loadApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Analisis wajah di dalam frame kamera.
  ///
  /// [livePresenceOnly] = true untuk pemantauan realtime (ringan),
  /// false untuk verifikasi resmi absensi (ketat + confidence akurat).
  /// [GeminiVerifierException.isAuthError] == true berarti masalah API key,
  /// agar UI bisa mengarahkan pengguna memperbaiki key.
  static Future<GeminiFaceResult> verifyFaceImage({
    required List<int> imageBytes,
    String mimeType = 'image/jpeg',
    bool livePresenceOnly = false,
    http.Client? client,
  }) async {
    final apiKey = await loadApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const GeminiVerifierException(
        'Gemini API key belum diisi.',
        isAuthError: true,
      );
    }

    final httpClient = client ?? http.Client();
    Object? lastError;

    for (final model in _modelChain) {
      try {
        return await _callModel(
          httpClient,
          apiKey: apiKey,
          model: model,
          imageBytes: imageBytes,
          mimeType: mimeType,
          livePresenceOnly: livePresenceOnly,
        );
      } on GeminiVerifierException catch (e) {
        if (e.message.contains('model')) {
          // Coba model fallback berikutnya
          lastError = e;
          continue;
        }
        rethrow;
      }
    }

    final err = lastError;
    if (err is GeminiVerifierException) {
      throw err;
    }
    throw const GeminiVerifierException(
      'Semua model Gemini tidak menerima respons.',
    );
  }

  static const _verifyPrompt = '''
Kamu adalah engine verifikasi wajah biometrik untuk aplikasi absensi enterprise.
Analisis foto yang diambil kamera (realtime snapshot) secara detail:

1. Apakah ada wajah manusia jelas di dalam frame? (wajah menghadap kamera, bagian wajah tidak tertutup, pencahayaan cukup)
2. Apakah wajah itu ORANG ASLI yang ada di depan kamera saat itu? Tolak keras jika terlihat seperti: foto orang di atas kertas/layar ponsel/monitor, printed image, masker, atau wajah buram sangat gelap.
3. Hitung nilai "confidence" 0.00-1.00 = tingkat keyakinan bahwa foto mengandung SATU wajah manusia asli, terang, jelas dan menghadap kamera. Foto buram/terlalu gelap = confidence rendah. Foto layar/printed = confidence di bawah 0.30 dan face_detected = false.
4. Hitung jumlah wajah yang muncul di frame (face_count); seseorang berfoto bersama orang lain dianggap anomali, tulis di message.

Balas HANYA dengan satu objek JSON valid tanpa penjelasan lain, format persis:
{"face_detected": bool, "face_count": int, "confidence": double 0.0-1.0, "message": "satu kalimat singkat"}''';

  static const _presencePrompt = '''
Analisis snapshot kamera ini untuk absensi wajah realtime.
Jalankan analisis cepat: apakah saat ini ada wajah manusia asli yang terlihat jelas,
menghadap kamera, dan cukup terang di frame?
Wajah di layar/foto dicetak TIDAK dihitung sebagai wajah asli.

Balas HANYA dengan satu objek JSON valid tanpa penjelasan lain, format persis:
{"face_detected": bool, "face_count": int, "confidence": double 0.0-1.0, "message": "satu kalimat singkat"}''';

  static Future<GeminiFaceResult> _callModel(
    http.Client httpClient, {
    required String apiKey,
    required String model,
    required List<int> imageBytes,
    required String mimeType,
    required bool livePresenceOnly,
  }) async {
    final prompt = livePresenceOnly ? _presencePrompt : _verifyPrompt;

    final isGemini25 = model.startsWith('gemini-2.5');
    final generationConfig = <String, dynamic>{
      'temperature': 0,
      'responseMimeType': 'application/json',
      if (isGemini25) 'thinkingConfig': <String, dynamic>{'thinkingBudget': 0},
    };

    final body = jsonEncode(<String, dynamic>{
      'contents': <Map<String, dynamic>>[
        {
          'parts': <Map<String, dynamic>>[
            {'text': prompt},
            {
              'inlineData': <String, dynamic>{
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': generationConfig,
    });

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final response = await httpClient
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 45));

    final decodedBody = jsonDecode(response.body);
    if (decodedBody is! Map<String, dynamic>) {
      throw GeminiVerifierException('Respons Gemini tidak valid.');
    }

    if (response.statusCode == 404 ||
        (decodedBody['error']?.toString() ?? '').contains('not found')) {
      throw GeminiVerifierException('Model $model tidak tersedia untuk key ini.');
    }

    if (response.statusCode == 400 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      final errorMap = decodedBody['error'];
      final reason =
          errorMap is Map<String, dynamic> ? errorMap['status'] ?? '' : '';
      if (reason.toString().contains('API_KEY_INVALID') ||
          reason.toString().contains('PERMISSION_DENIED')) {
        throw const GeminiVerifierException(
          'Gemini API key ditolak server (invalid atau dibatasi).',
          isAuthError: true,
        );
      }
    }

    if (response.statusCode == 429) {
      throw const GeminiVerifierException(
        'Kuota Gemini mencapai batas, coba lagi nanti.',
      );
    }

    if (response.statusCode != 200) {
      throw GeminiVerifierException(
        'Gemini error ${response.statusCode}: ${decodedBody['error'] ?? 'unknown'}',
      );
    }

    final candidates = decodedBody['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw GeminiVerifierException(
        'Gemini tidak mengembalikan analisis (respons kosong).',
      );
    }
    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) {
      throw GeminiVerifierException('Format respons Gemini tidak dikenal.');
    }

    final content = candidate['content'];
    final parts = content is Map<String, dynamic> ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw GeminiVerifierException(
        'Gemini tidak mengembalikan teks analisis.',
      );
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic> && part['text'] is String) {
        buffer.write(part['text']);
      }
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw GeminiVerifierException(
        'Gemini mengembalikan analisis kosong.',
      );
    }

    return _parseResult(text, model);
  }

  static GeminiFaceResult _parseResult(String raw, String model) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp('^```(json)?'), '')
          .replaceAll('```', '')
          .trim();
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      json = decoded;
    } catch (_) {
      throw GeminiVerifierException(
        'Gemini mengembalikan format tidak terduga: $raw',
      );
    }

    final faceDetected = json['face_detected'] == true ||
        json['face_detected'].toString().toLowerCase() == 'true';
    final faceCount = int.tryParse(json['face_count'].toString()) ??
        (faceDetected ? 1 : 0);
    final confidence = (double.tryParse(json['confidence'].toString())
                ??
                0.0)
            .clamp(0.0, 1.0)
            .toDouble();
    final message =
        json['message']?.toString() ?? (faceDetected ? 'Wajah terdeteksi.' : '');

    return GeminiFaceResult(
      faceDetected: faceDetected,
      faceCount: faceCount,
      confidence: confidence,
      message: message,
      model: model,
    );
  }
}
