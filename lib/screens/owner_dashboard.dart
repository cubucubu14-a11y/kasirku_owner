import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ==========================================
// KELAS API (Digabung ke sini)
// ==========================================
class ApiService {
  static Future<List<String>> getDaftarCabang(String url) async {
    final uri = Uri.parse(url).replace(queryParameters: {'action': 'getDaftarCabang'});
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded['status'] != 'success') throw Exception(decoded['message']);
    return (decoded['data'] as List).map((e) => e.toString()).toList();
  }

  static Future<Map<String, dynamic>> tarikSemuaData({
    required String url, required String cb, required String filter, String? tglMulai, String? tglAkhir,
  }) async {
    final Map<String, String> qp = {'action': 'tarikSemuaData', 'cb': cb, 'filter': filter};
    if (filter == 'custom' && tglMulai != null && tglAkhir != null) {
      qp['tgl_mulai'] = tglMulai; qp['tgl_akhir'] = tglAkhir;
    }
    final uri = Uri.parse(url).replace(queryParameters: qp);
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded['status'] != 'success') throw Exception(decoded['message']);
    return decoded['data'] as Map<String, dynamic>;
  }
}

// ==========================================
// KELAS UI DASHBOARD
// ==========================================
class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final String urlApi = 'https://script.google.com/macros/s/AKfycbxJBGAB528qEb8bpSzKMU0h_MkQ5_X0xaMbKphy1iffkdy6zsIajuoEi1LRzCpnnIM/exec';

  bool _isLoading = true;
  String _errorMessage = '';
  List<String> _daftarCabang = ['Semua'];
  String _cabangAktif = 'Semua';
  String _filterTanggal = 'bulan_ini';
  DateTimeRange? _customDateRange;
  Map<String, dynamic>? _dataDashboard;

  final Color _bgColor = const Color(0xFF0F111A);
  final Color _cardColor = const Color(0xFF1E1E2C);
  final Color _primaryColor = const Color(0xFF8A78E5);
  final Color _textMuted = const Color(0xFFA0A0B0);

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cabangAktif = prefs.getString('cabang_aktif') ?? 'Semua';
      _filterTanggal = prefs.getString('filter_tanggal') ?? 'bulan_ini';
    });
    try {
      final list = await ApiService.getDaftarCabang(urlApi);
      setState(() {
        _daftarCabang = list;
        if (!_daftarCabang.contains(_cabangAktif)) _cabangAktif = 'Semua';
      });
    } catch (e) {}
    _fetchDataDashboard();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cabang_aktif', _cabangAktif);
    await prefs.setString('filter_tanggal', _filterTanggal);
  }

  Future<void> _fetchDataDashboard() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      String? startStr, endStr;
      if (_filterTanggal == 'custom' && _customDateRange != null) {
        startStr = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
        endStr = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
      }
      final result = await ApiService.tarikSemuaData(
        url: urlApi, cb: _cabangAktif, filter: _filterTanggal, tglMulai: startStr, tglAkhir: endStr,
      );
      setState(() { _dataDashboard = result; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  String _formatRupiah(dynamic number) {
    if (number == null) return 'Rp 0';
    final parsed = double.tryParse(number.toString()) ?? 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(parsed);
  }

  String _getFilterLabel() {
    if (_filterTanggal == 'hari_ini') return 'Hari Ini';
    if (_filterTanggal == 'minggu_ini') return 'Minggu Ini';
    if (_filterTanggal == 'bulan_ini') return 'Bulan Ini';
    if (_customDateRange != null) {
      return '${DateFormat('d MMM').format(_customDateRange!.start)} - ${DateFormat('d MMM').format(_customDateRange!.end)}';
    }
    return 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDataDashboard,
          color: _primaryColor,
          child: Column(
            children: [
              _buildHeader(),
              _buildFilterChips(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A78E5)))
                    : _errorMessage.isNotEmpty ? _buildError() : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard Owner', style: TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                color: _cardColor,
                offset: const Offset(0, 40),
                onSelected: (val) { setState(() => _cabangAktif = val); _savePrefs(); _fetchDataDashboard(); },
                itemBuilder: (ctx) => _daftarCabang.map((c) => PopupMenuItem(
                  value: c,
                  child: Text(c == 'Semua' ? '🏢 Semua Cabang' : c, style: TextStyle(color: c == _cabangAktif ? _primaryColor : Colors.white)),
                )).toList(),
                child: Row(
                  children: [
                    Text(_cabangAktif == 'Semua' ? 'Semua Cabang' : _cabangAktif, style: TextStyle(color: _textMuted, fontSize: 14)),
                    Icon(Icons.arrow_drop_down, color: _textMuted),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchDataDashboard),
              IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () {}),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _chip('Hari Ini', 'hari_ini'), const SizedBox(width: 8),
          _chip('Minggu Ini', 'minggu_ini'), const SizedBox(width: 8),
          _chip('Bulan Ini', 'bulan_ini'), const SizedBox(width: 8),
          ActionChip(
            backgroundColor: _filterTanggal == 'custom' ? _primaryColor : _cardColor,
            label: Text(_getFilterLabel(), style: TextStyle(color: _filterTanggal == 'custom' ? Colors.white : _textMuted, fontSize: 13)),
            onPressed: () async {
              final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now());
              if (picked != null) { setState(() { _customDateRange = picked; _filterTanggal = 'custom'; }); _savePrefs(); _fetchDataDashboard(); }
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String val) {
    final active = _filterTanggal == val;
    return GestureDetector(
      onTap: () { setState(() => _filterTanggal = val); _savePrefs(); _fetchDataDashboard(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: active ? _primaryColor : _cardColor, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : _textMuted, fontSize: 13)),
      ),
    );
  }

  Widget _buildError() {
    return Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.white), textAlign: TextAlign.center));
  }

  Widget _buildContent() {
    if (_dataDashboard == null) return const SizedBox();
    final total = _dataDashboard!['total'];
    final isSemua = _cabangAktif == 'Semua';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Ringkasan penjualan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _card('Omset', _formatRupiah(total['omset']))),
          const SizedBox(width: 12),
          Expanded(child: _card('Transaksi', '${total['trx']}')),
        ]),
        const SizedBox(height: 24),
        if (!isSemua) ...[
          const Text('Produk terlaris', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._listProduk(_dataDashboard!['produk_global']),
        ],
        if (isSemua) ...[
          const Text('Rincian Kinerja Cabang', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._listRincian(total['omset']),
        ],
      ],
    );
  }

  Widget _card(String title, String val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: _textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  List<Widget> _listProduk(List<dynamic> list) {
    if (list.isEmpty) return [const Text('Belum ada data', style: TextStyle(color: Colors.grey))];
    return list.map((p) => Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(p['nama'], style: const TextStyle(color: Colors.white)),
        Text('${p['qty']} qty', style: TextStyle(color: _textMuted)),
      ]),
    )).toList();
  }

  List<Widget> _listRincian(dynamic totalOmsetGlobal) {
    final list = _dataDashboard!['rincian_cabang'] as List<dynamic>;
    final total = double.tryParse(totalOmsetGlobal.toString()) ?? 1;
    return list.map((r) {
      final persen = (double.tryParse(r['omset'].toString()) ?? 0) / total * 100;
      return GestureDetector(
        onTap: () { setState(() => _cabangAktif = r['nama']); _savePrefs(); _fetchDataDashboard(); },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A27), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r['nama'], style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
              Text(_formatRupiah(r['omset']), style: const TextStyle(color: Colors.white)),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Kontribusi: ${persen.toStringAsFixed(1)}%', style: TextStyle(color: _textMuted, fontSize: 12))),
          ]),
        ),
      );
    }).toList();
  }
}
