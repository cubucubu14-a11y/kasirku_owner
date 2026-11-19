import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<List<Map<String, dynamic>>> tarikSemuaData(
    String url,
    String namaCabang,
  ) async {
    try {
      // 1. Susun URL dengan parameter
      final uri = Uri.parse(url).replace(queryParameters: {
        'action': 'tarikSemuaData',
        'nama_cabang': namaCabang,
      });

      // 2. Gunakan GET (BUKAN POST)
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      final body = utf8.decode(response.bodyBytes).trim();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${body.isEmpty ? "respons kosong" : body}');
      }
      if (body.isEmpty) throw Exception('Respons kosong');

      final decoded = jsonDecode(body);

      if (decoded['status'] != 'success') {
        throw Exception(decoded['message']?.toString() ?? 'Ditolak');
      }

      final data = decoded['data'];
      if (data is! List) throw Exception('Data bukan list');

      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();

    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
