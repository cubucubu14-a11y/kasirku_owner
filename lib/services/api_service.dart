import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<List<Map<String, dynamic>>> tarikSemuaData(
    String url,
    String namaCabang,
  ) async {
    // 1. Menggunakan Client khusus untuk kontrol redirect
    final client = http.Client();
    
    try {
      // 2. Menggunakan http.Request (bukan http.post) agar bisa atur redirect manual
      final request = http.Request('POST', Uri.parse(url));
      
      // 3. Set Header wajib untuk Apps Script
      request.headers['Content-Type'] = 'application/json; charset=UTF-8';
      
      // 4. Masukkan data ke body
      request.body = jsonEncode({
        'action': 'tarikSemuaData',
        'nama_cabang': namaCabang,
      });
      
      // 5. KUNCI PERBAIKAN: Paksa ikuti redirect Google (solusi Error 302)
      request.followRedirects = true;
      request.maxRedirects = 5;

      // 6. Kirim request
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 30));
      
      // 7. Ubah stream response ke bentuk response standar
      final response = await http.Response.fromStream(streamedResponse);

      // 8. Ambil body dan decode UTF-8
      final body = utf8.decode(response.bodyBytes).trim();

      // 9. Validasi Status Code (Jika masih error)
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${body.isEmpty ? "respons kosong" : body}');
      }

      if (body.isEmpty) {
        throw Exception('Apps Script mengembalikan respons kosong');
      }

      // 10. Decode JSON dari Google
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

      // 11. Kembalikan data dalam bentuk List of Map
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
          
    } finally {
      // 12. Wajib tutup client setelah selesai
      client.close(); 
    }
  }
}
