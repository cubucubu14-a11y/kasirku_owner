import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  static const _urlKey = 'apps_script_url';
  static const _cabangKey = 'nama_cabang';

  final List<Map<String, dynamic>> _transaksi = [];
  bool _isLoading = false;
  String _url = '';
  String _namaCabang = '';
  String? _errorMessage;

  static const _background = Color(0xFF10131A);
  static const _surface = Color(0xFF1A1F2B);
  static const _muted = Color(0xFF9AA4B2);
  static const _accent = Color(0xFF8B7CFF);

  @override
  void initState() {
    super.initState();
    _loadPengaturan();
  }

  Future<void> _loadPengaturan() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _url = preferences.getString(_urlKey) ?? '';
      _namaCabang = preferences.getString(_cabangKey) ?? '';
    });
  }

  Future<void> _bukaPengaturan() async {
    final urlController = TextEditingController(text: _url);
    final cabangController = TextEditingController(text: _namaCabang);

    final pengaturan = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Pengaturan koneksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL Apps Script',
                hintText: 'https://script.google.com/...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cabangController,
              decoration: const InputDecoration(labelText: 'Nama Cabang'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'url': urlController.text.trim(),
              'cabang': cabangController.text.trim(),
            }),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    urlController.dispose();
    cabangController.dispose();

    if (pengaturan == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_urlKey, pengaturan['url'] ?? '');
    await preferences.setString(_cabangKey, pengaturan['cabang'] ?? '');
    if (!mounted) return;
    setState(() {
      _url = pengaturan['url'] ?? '';
      _namaCabang = pengaturan['cabang'] ?? '';
    });
    _tampilkanPesan('Pengaturan berhasil disimpan.');
  }

  Future<void> _tarikData() async {
    if (_url.isEmpty || _namaCabang.isEmpty) {
      _tampilkanPesan('Isi URL Apps Script dan Nama Cabang melalui Pengaturan.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await ApiService.tarikSemuaData(_url, _namaCabang);
      if (!mounted) return;
      setState(() {
        _transaksi
          ..clear()
          ..addAll(data);
      });
      _tampilkanPesan('Data berhasil diperbarui.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Gagal mengambil data: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _tampilkanPesan(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  double _angka(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    final normalized = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  double _nilaiPertama(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      if (item[key] != null) return _angka(item[key]);
    }
    return 0;
  }

  String _teksPertama(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return 'Lainnya';
  }

  double get _totalOmset => _transaksi.fold<double>(
        0,
        (total, transaksi) =>
            total + _nilaiPertama(transaksi, ['total', 'total_transaksi', 'nominal']),
      );

  double _totalMetode(List<String> metodeYangDicari) {
    return _transaksi.where((transaksi) {
      final metode = _teksPertama(
        transaksi,
        ['metode_pembayaran', 'metode', 'payment_method'],
      ).toLowerCase();
      return metodeYangDicari.any(metode.contains);
    }).fold<double>(
      0,
      (total, transaksi) =>
          total + _nilaiPertama(transaksi, ['total', 'total_transaksi', 'nominal']),
    );
  }

  List<_ProdukTerlaris> get _produkTerlaris {
    final agregat = <String, _ProdukTerlaris>{};
    for (final transaksi in _transaksi) {
      final detail = transaksi['detail_produk'];
      dynamic parsed = detail;
      if (detail is String) {
        try {
          parsed = jsonDecode(detail);
        } on FormatException {
          continue;
        }
      }
      if (parsed is! List) continue;

      for (final item in parsed) {
        if (item is! Map) continue;
        final produk = Map<String, dynamic>.from(item);
        final nama = _teksPertama(
          produk,
          ['nama_produk', 'nama', 'produk', 'product_name'],
        );
        final qty = _nilaiPertama(produk, ['qty', 'jumlah', 'quantity']);
        final nominalTersedia = [
          'subtotal',
          'nominal',
          'total',
          'total_harga',
        ].firstWhere((key) => produk[key] != null, orElse: () => '');
        final nominal = nominalTersedia.isNotEmpty
            ? _angka(produk[nominalTersedia])
            : _nilaiPertama(produk, ['harga', 'harga_satuan', 'price']) * qty;
        final ringkasan = agregat.putIfAbsent(
          nama,
          () => _ProdukTerlaris(nama: nama),
        );
        ringkasan
          ..qty += qty
          ..nominal += nominal;
      }
    }
    final hasil = agregat.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    return hasil;
  }

  String _formatRupiah(double value) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(value);

  @override
  Widget build(BuildContext context) {
    final produk = _produkTerlaris;
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          surface: _surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(color: _surface),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard Owner'),
              if (_namaCabang.isNotEmpty)
                Text(
                  _namaCabang,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Tarik data',
              onPressed: _isLoading ? null : _tarikData,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
            IconButton(
              tooltip: 'Pengaturan',
              onPressed: _bukaPengaturan,
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _tarikData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null) ...[
                  _PesanError(pesan: _errorMessage!),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Ringkasan penjualan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.65,
                  children: [
                    _KartuRingkasan(
                      judul: 'Total Omset',
                      nilai: _formatRupiah(_totalOmset),
                      ikon: Icons.trending_up,
                      warna: const Color(0xFF8B7CFF),
                    ),
                    _KartuRingkasan(
                      judul: 'Total Transaksi',
                      nilai: _transaksi.length.toString(),
                      ikon: Icons.receipt_long_outlined,
                      warna: const Color(0xFF56C8A3),
                    ),
                    _KartuRingkasan(
                      judul: 'Total Tunai',
                      nilai: _formatRupiah(_totalMetode(['tunai', 'cash'])),
                      ikon: Icons.payments_outlined,
                      warna: const Color(0xFFFFB45C),
                    ),
                    _KartuRingkasan(
                      judul: 'Total QRIS',
                      nilai: _formatRupiah(_totalMetode(['qris'])),
                      ikon: Icons.qr_code_2,
                      warna: const Color(0xFF63B8FF),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Produk terlaris',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (produk.isEmpty)
                  const Card(
                    color: _surface,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Belum ada data produk untuk ditampilkan.',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  )
                else
                  _GrafikProduk(
                    produk: produk,
                    formatRupiah: _formatRupiah,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProdukTerlaris {
  _ProdukTerlaris({required this.nama});

  final String nama;
  double qty = 0;
  double nominal = 0;
}

class _KartuRingkasan extends StatelessWidget {
  const _KartuRingkasan({
    required this.judul,
    required this.nilai,
    required this.ikon,
    required this.warna,
  });

  final String judul;
  final String nilai;
  final IconData ikon;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(ikon, color: warna, size: 25),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(judul, style: const TextStyle(color: Color(0xFF9AA4B2))),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      nilai,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrafikProduk extends StatelessWidget {
  const _GrafikProduk({required this.produk, required this.formatRupiah});

  final List<_ProdukTerlaris> produk;
  final String Function(double) formatRupiah;

  @override
  Widget build(BuildContext context) {
    final maxQty = produk.fold<double>(
      0,
      (maxValue, item) => item.qty > maxValue ? item.qty : maxValue,
    );

    return Card(
      color: const Color(0xFF1A1F2B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final item in produk)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fraction = maxQty == 0 ? 0.0 : item.qty / maxQty;
                    final barWidth = constraints.maxWidth * fraction;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${_formatQty(item.qty)} qty'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A3040),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: barWidth,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B7CFF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          formatRupiah(item.nominal),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9AA4B2),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatQty(double qty) =>
      qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
}

class _PesanError extends StatelessWidget {
  const _PesanError({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF492B35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(pesan, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
