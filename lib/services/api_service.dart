import 'dart:convert';
import 'package:dio/dio.dart';

class ApiService {
  static Future<List<Map<String, dynamic>>> tarikSemuaData(
    String url,
    String namaCabang,
  ) async {
    // 1. Setup Dio dengan pengaturan anti-redirect-error
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true, // KUNCI UTAMA
      maxRedirects: 5,
      responseType: ResponseType.plain, // Ambil teks mentah dulu
    ));

    try {
      // 2. Kirim POST request
      final response = await dio.post(
        url,
        data: jsonEncode({
          'action': 'tarikSemuaData',
          'nama_cabang': namaCabang,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
        ),
      );

      final body = response.data.toString().trim();

      if (body.isEmpty) {
        throw Exception('Apps Script mengembalikan respons kosong');
      }

      // 3. Decode JSON
      final dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        throw Exception('Respons bukan JSON: $body');
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Format respons harus berupa JSON objek');
      }

      if (decoded['status'] != 'success') {
        throw Exception(decoded['message']?.toString() ?? 'Permintaan ditolak oleh Apps Script');
      }

      final data = decoded['data'];
      if (data is! List) {
        throw Exception('Field data bukan daftar JSON');
      }

      // 4. Return data
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

    } on DioException catch (e) {
      // Tangkap error dari Dio
      if (e.response != null) {
        throw Exception('HTTP ${e.response?.statusCode}: ${e.response?.data}');
      }
      throw Exception('Koneksi gagal: ${e.message}');
    }
  }
}
