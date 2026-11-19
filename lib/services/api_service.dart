import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static Future<List<Map<String, dynamic>>> tarikSemuaData(
    String url,
    String namaCabang,
  ) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            'action': 'tarikSemuaData',
            'nama_cabang': namaCabang,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = utf8.decode(response.bodyBytes).trim();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${body.isEmpty ? "respons kosong" : body}');
    }

    if (body.isEmpty) {
      throw Exception('Apps Script mengembalikan respons kosong');
    }

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

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
