import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ==========================================
// KELAS API (Digabung untuk menghindari error path)
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
    required String url, 
    required String cb, 
    required String filter, 
    String? tglMulai, 
    String? tglAkhir,
  }) async {
    final Map<String, String> qp = {'action': 'tarikSemuaData', 'cb': cb, 'filter': filter};
    if (filter == 'custom' && tglMulai != null && tglAkhir != null) {
      qp['tgl_mulai'] = tglMulai; 
      qp['tgl_akhir'] = tglAkhir;
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
    } catch (e) {
      // Abaikan error daftar cabang
    }
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
    if (_filterTanggal == 'custom') {
      if (_customDateRange != null) {
        return '${DateFormat('d MMM').format(_customDateRange!.start)} - ${DateFormat('d MMM').format(_customDateRange!.end)}';
      }
      return 'Custom'; 
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
                onSelected: (val) { 
                  setState(() => _cabangAktif = val); 
                  _savePrefs(); 
                  _fetchDataDashboard(); 
                },
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
            side: BorderSide(color: _filterTanggal == 'custom' ? _primaryColor : Colors.grey[800]!),
            avatar: Icon(Icons.calendar_today, size: 14, color: _filterTanggal == 'custom' ? Colors.white : _textMuted),
            label: Text(_getFilterLabel(), style: TextStyle(color: _filterTanggal == 'custom' ? Colors.white : _textMuted, fontSize: 13)),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context, 
                firstDate: DateTime(2023), 
                lastDate: DateTime.now(),
                builder: (context, child) => Theme(
                  data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: _primaryColor)), 
                  child: child!
                ),
              );
              if (picked != null) { 
                setState(() { _customDateRange = picked; _filterTanggal = 'custom'; }); 
                _savePrefs(); 
                _fetchDataDashboard(); 
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String val) {
    final active = _filterTanggal == val;
    return GestureDetector(
      onTap: () { 
        setState(() => _filterTanggal = val); 
        _savePrefs(); 
        _fetchDataDashboard(); 
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _primaryColor : _cardColor, 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _primaryColor : Colors.grey[800]!),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : _textMuted, fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text('Gagal mengambil data:\n$_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDataDashboard, 
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor), 
              child: const Text('Coba Lagi')
            )
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_dataDashboard == null) return const SizedBox();
    final total = _dataDashboard!['total'];
    final isSemua = _cabangAktif == 'Semua';

    return ListView(
      // Tambahan bottom: 100 agar list tidak terpotong
      padding: const EdgeInsets.all(20).copyWith(bottom: 100), 
      children: [
        const Text('Ringkasan penjualan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _card('Omset', _formatRupiah(total['omset']))),
          const SizedBox(width: 12),
          Expanded(child: _card('Transaksi', '${total['trx']}')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _card('Tunai', _formatRupiah(total['tunai']))),
          const SizedBox(width: 12),
          Expanded(child: _card('QRIS', _formatRupiah(total['qris']))),
        ]),
        const SizedBox(height: 24),
        
        // TAMPILAN PRODUK TERLARIS (1 Cabang)
        if (!isSemua) ...[
          const Text('Produk terlaris', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._listProduk(_dataDashboard!['produk_global']),
        ],
        
        // TAMPILAN RINCIAN CABANG (Mode Semua)
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
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ==========================================
  // FUNGSI GRAFIK PRODUK TERLARIS (DIPERBARUI)
  // ==========================================
  List<Widget> _listProduk(List<dynamic> list) {
    if (list.isEmpty) {
      return [const Center(child: Text('Belum ada data produk.', style: TextStyle(color: Colors.grey)))];
    }
    
    // 1. Cari QTY terbanyak untuk menentukan panjang grafik (100%)
    int maxQty = 1;
    for(var p in list) {
      final qty = int.tryParse(p['qty']?.toString() ?? '0') ?? 0;
      if(qty > maxQty) maxQty = qty; 
    }

    // 2. Buat daftar widget-nya
    return list.map((p) {
      final nama = p['nama']?.toString() ?? 'Tanpa Nama';
      final qty = int.tryParse(p['qty']?.toString() ?? '0') ?? 0;
      final harga = p['harga']; 
      
      // Hitung persentase grafik (0.0 sampai 1.0)
      final double persen = maxQty > 0 ? (qty / maxQty) : 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 12), 
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor, 
          borderRadius: BorderRadius.circular(12)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Atas: Nama Produk & Qty
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text(nama, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('$qty qty', style: TextStyle(color: _textMuted, fontSize: 14)),
              ]
            ),
            const SizedBox(height: 8),
            
            // Grafik Batang (Progress Bar)
            LinearProgressIndicator(
              value: persen, 
              backgroundColor: Colors.grey[800], 
              color: _primaryColor, 
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            
            const SizedBox(height: 8),
            
            // Baris Bawah: Harga
            Text(_formatRupiah(harga), style: TextStyle(color: _textMuted, fontSize: 12)),
          ],
        ),
      );
    }).toList();
  }

  // ==========================================
  // FUNGSI RINCIAN CABANG (MODE SEMUA)
  // ==========================================
  List<Widget> _listRincian(dynamic totalOmsetGlobal) {
    final list = _dataDashboard!['rincian_cabang'] as List<dynamic>;
    final total = double.tryParse(totalOmsetGlobal.toString()) ?? 1;
    
    return list.map((r) {
      final persen = (double.tryParse(r['omset'].toString()) ?? 0) / total * 100;
      return GestureDetector(
        onTap: () { 
          setState(() => _cabangAktif = r['nama']); 
          _savePrefs(); 
          _fetchDataDashboard(); 
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12), 
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A27), 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A3C)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['nama'], style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF2A2A3C), borderRadius: BorderRadius.circular(12)),
                    child: Text('Kontribusi: ${persen.toStringAsFixed(1)}%', style: TextStyle(color: _textMuted, fontSize: 11)),
                  ),
                ]
              ),
              Row(
                children: [
                  Text(_formatRupiah(r['omset']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: _textMuted, size: 20),
                ],
              )
            ]),
            const Divider(color: Color(0xFF333333), height: 24),
            Align(
              alignment: Alignment.centerLeft, 
              child: Text('Terlaris di cabang ini:', style: TextStyle(color: _textMuted, fontSize: 12, fontStyle: FontStyle.italic))
            ),
            const SizedBox(height: 8),
            
            // Menampilkan Produk Per Cabang (Di dalam Rincian)
            ...(r['produk'] as List<dynamic>).map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(p['nama'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('${p['qty']} qty', style: TextStyle(color: _textMuted, fontSize: 13)),
                ]),
              );
            }),
          ]),
        ),
      );
    }).toList();
  }
}
