import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart'; // <-- Import sudah diperbaiki

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
    await _loadPreferences();
    await _fetchDaftarCabang();
    await _fetchDataDashboard();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cabangAktif = prefs.getString('cabang_aktif') ?? 'Semua';
      _filterTanggal = prefs.getString('filter_tanggal') ?? 'bulan_ini';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cabang_aktif', _cabangAktif);
    await prefs.setString('filter_tanggal', _filterTanggal);
  }

  Future<void> _fetchDaftarCabang() async {
    try {
      final list = await ApiService.getDaftarCabang(urlApi);
      setState(() {
        _daftarCabang = list;
        if (!_daftarCabang.contains(_cabangAktif)) _cabangAktif = 'Semua';
      });
    } catch (e) {}
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
    switch (_filterTanggal) {
      case 'hari_ini': return 'Hari Ini';
      case 'minggu_ini': return 'Minggu Ini';
      case 'bulan_ini': return 'Bulan Ini';
      case 'custom':
        if (_customDateRange != null) {
          return '${DateFormat('d MMM').format(_customDateRange!.start)} - ${DateFormat('d MMM').format(_customDateRange!.end)}';
        }
        return 'Custom';
      default: return 'Pilih Tanggal';
    }
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
                    : _errorMessage.isNotEmpty ? _buildErrorState() : _buildContent(),
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
              const Text('Dashboard Owner', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400)),
              const SizedBox(height: 4),
              _buildDropdownCabang(),
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

  Widget _buildDropdownCabang() {
    return PopupMenuButton<String>(
      color: _cardColor,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (String newValue) {
        if (newValue != _cabangAktif) {
          setState(() { _cabangAktif = newValue; });
          _savePreferences();
          _fetchDataDashboard();
        }
      },
      itemBuilder: (BuildContext context) {
        return _daftarCabang.map((String cabang) {
          final isSelected = cabang == _cabangAktif;
          final isSemua = cabang == 'Semua';
          return PopupMenuItem<String>(
            value: cabang,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isSemua ? '🏢 Semua Cabang (Total)' : cabang,
                    style: TextStyle(color: isSelected ? _primaryColor : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected) Icon(Icons.check, color: _primaryColor, size: 18),
              ],
            ),
          );
        }).toList();
      },
      child: Row(
        children: [
          Text(_cabangAktif == 'Semua' ? 'Semua Cabang' : _cabangAktif, style: TextStyle(color: _textMuted, fontSize: 14)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, color: _textMuted, size: 20),
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
          _buildChip('Hari Ini', 'hari_ini'), const SizedBox(width: 8),
          _buildChip('Minggu Ini', 'minggu_ini'), const SizedBox(width: 8),
          _buildChip('Bulan Ini', 'bulan_ini'), const SizedBox(width: 8),
          ActionChip(
            backgroundColor: _filterTanggal == 'custom' ? _primaryColor : _cardColor,
            side: BorderSide(color: _filterTanggal == 'custom' ? _primaryColor : Colors.grey[800]!),
            avatar: Icon(Icons.calendar_today, size: 14, color: _filterTanggal == 'custom' ? Colors.white : _textMuted),
            label: Text(_getFilterLabel(), style: TextStyle(color: _filterTanggal == 'custom' ? Colors.white : _textMuted, fontWeight: _filterTanggal == 'custom' ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context, firstDate: DateTime(2023), lastDate: DateTime.now(),
                builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: _primaryColor)), child: child!),
              );
              if (picked != null) {
                setState(() { _customDateRange = picked; _filterTanggal = 'custom'; });
                _savePreferences();
                _fetchDataDashboard();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isActive = _filterTanggal == value;
    return GestureDetector(
      onTap: () {
        setState(() { _filterTanggal = value; });
        _savePreferences();
        _fetchDataDashboard();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isActive ? _primaryColor : _cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isActive ? _primaryColor : Colors.grey[800]!)),
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : _textMuted, fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildErrorState() {
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
            ElevatedButton(onPressed: _fetchDataDashboard, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor), child: const Text('Coba Lagi'))
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
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Ringkasan penjualan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildSummaryCard('Total Omset', _formatRupiah(total['omset']), Icons.show_chart, Colors.purpleAccent)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Total Transaksi', '${total['trx']}', Icons.receipt, Colors.tealAccent)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildSummaryCard('Total Tunai', _formatRupiah(total['tunai']), Icons.money, Colors.orangeAccent)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Total QRIS', _formatRupiah(total['qris']), Icons.qr_code, Colors.blueAccent)),
        ]),
        const SizedBox(height: 24),
        if (!isSemua) ...[
          const Text('Produk terlaris', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._buildProdukList(_dataDashboard!['produk_global']),
        ],
        if (isSemua) ...[
          const Text('Rincian Kinerja Cabang', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._buildRincianCabangList(total['omset']),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: _textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildProdukList(List<dynamic> produkList) {
    if (produkList.isEmpty) return [const Center(child: Text('Belum ada data produk.', style: TextStyle(color: Colors.grey)))];
    int maxQty = 1;
    for(var p in produkList) { if(p['qty'] > maxQty) maxQty = p['qty']; }
    return produkList.map((p) {
      double persen = (p['qty'] / maxQty);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(p['nama'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${p['qty']} qty', style: TextStyle(color: _textMuted)),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: persen, backgroundColor: Colors.grey[800], color: _primaryColor, minHeight: 6),
            const SizedBox(height: 8),
            Text(_formatRupiah(p['harga']), style: TextStyle(color: _textMuted, fontSize: 12)),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildRincianCabangList(dynamic totalOmsetGlobal) {
    final rincianList = _dataDashboard!['rincian_cabang'] as List<dynamic>;
    final double totalOmset = double.tryParse(totalOmsetGlobal.toString()) ?? 1;

    return rincianList.map((r) {
      final double omsetCabang = double.tryParse(r['omset'].toString()) ?? 0;
      final double persentase = totalOmset > 0 ? (omsetCabang / totalOmset) * 100 : 0;

      return GestureDetector(
        onTap: () {
          setState(() { _cabangAktif = r['nama']; });
          _savePreferences();
          _fetchDataDashboard();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A27), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A3C))),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['nama'], style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF2A2A3C), borderRadius: BorderRadius.circular(12)),
                    child: Text('Kontribusi: ${persentase.toStringAsFixed(1)}%', style: TextStyle(color: _textMuted, fontSize: 11)),
                  ),
                ]),
                Row(children: [
                  Text(_formatRupiah(r['omset']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: _textMuted, size: 20),
                ])
              ]),
              const Divider(color: Color(0xFF333333), height: 24),
              Align(alignment: Alignment.centerLeft, child: Text('Terlaris di cabang ini:', style: TextStyle(color: _textMuted, fontSize: 12, fontStyle: FontStyle.italic))),
              const SizedBox(height: 8),
              ...(r['produk'] as List<dynamic>).map((p) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(p['nama'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('${p['qty']} qty', style: TextStyle(color: _textMuted, fontSize: 13)),
                  ]),
                );
              }),
            ],
          ),
        ),
      );
    }).toList();
  }
}
