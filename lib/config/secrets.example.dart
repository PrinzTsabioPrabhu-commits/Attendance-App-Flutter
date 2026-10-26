/// TEMPLATE SECRETS (COMMIT-SAFE).
///
/// Salin file ini menjadi `secrets.dart` (harusnya otomatis di-ignore git),
/// lalu isi nilainya. File `secrets.dart` asli TIDAK boleh di-commit
/// karena berisi API key.
///
/// Alternatif: biarkan kosong dan masukkan API key lewat dialog
/// "Gemini API Key" di dalam aplikasi saat pertama kali Scan Face di web.
class Secrets {
  Secrets._();

  /// API key Gemini (diawali `AIza...` atau `AQ.Ab8...` dari Google AI Studio)
  static const String geminiApiKey = ''; // <-- isi local, jangan commit
}
