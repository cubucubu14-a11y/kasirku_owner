import 'package:flutter/material.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.attach_money,
                  color: Colors.green,
                ),
                title: const Text('Total Omzet'),
                subtitle: const Text('Rp 12.500.000'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.shopping_cart,
                  color: Colors.blue,
                ),
                title: const Text('Total Transaksi'),
                subtitle: const Text('120 Transaksi'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.inventory,
                  color: Colors.orange,
                ),
                title: const Text('Jumlah Produk'),
                subtitle: const Text('45 Produk'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.analytics),
                label: const Text('Lihat Laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
