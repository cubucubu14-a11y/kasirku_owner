import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static Future<List<Map<String, dynamic>>> tarikSemuaData(
    String url,
    String namaCabang,
  ) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'tarikSemuaData',
        'nama_cabang': namaCabang,
      }),
    );

    final hasil = jsonDecode(response.body) as Map<String, dynamic>;
    if (hasil['status'] != 'success') return [];

    final data = hasil['data'];
    if (data is! List) return [];

    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
