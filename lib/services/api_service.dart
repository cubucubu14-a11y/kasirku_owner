import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // =========================================================================
  // 1. FUNGSI AMBIL DAFTAR CABANG
  // =========================================================================
  static Future<List<String>> getDaftarCabang(String url) async {
    try {
      final uri = Uri.parse(url).replace(queryParameters: {
        'action': 'getDaftarCabang',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      final body = utf8.decode(response.bodyBytes).trim();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }

      final decoded = jsonDecode(body);
      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Gagal mengambil daftar cabang');
      }

      final List<dynamic> data = decoded['data'];
      return data.map((e) => e.toString()).toList();
      
    } catch (e) {
      throw Exception('Gagal koneksi daftar cabang: $e');
    }
  }

  // =========================================================================
  // 2. FUNGSI TARIK DATA DASHBOARD
  // =========================================================================
  static Future<Map<String, dynamic>> tarikSemuaData({
    required String url,
    required String cb,
    required String filter, // 'hari_ini', 'minggu_ini', 'bulan_ini', 'custom'
    String? tglMulai,
    String? tglAkhir,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'action': 'tarikSemuaData',
        'cb': cb,
        'filter': filter,
      };

      if (filter == 'custom' && tglMulai != null && tglAkhir != null) {
        queryParams['tgl_mulai'] = tglMulai;
        queryParams['tgl_akhir'] = tglAkhir;
      }

      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      final body = utf8.decode(response.bodyBytes).trim();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }
      
      if (body.isEmpty) {
        throw Exception('Apps Script mengembalikan respons kosong');
      }

      final decoded = jsonDecode(body);
      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Gagal mengambil data dashboard');
      }

      return decoded['data'] as Map<String, dynamic>;

    } catch (e) {
      throw Exception('Gagal koneksi data dashboard: $e');
    }
  }
}
