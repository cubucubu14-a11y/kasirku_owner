import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppScriptSettingsScreen extends StatefulWidget {
  const AppScriptSettingsScreen({super.key});

  @override
  State<AppScriptSettingsScreen> createState() =>
      _AppScriptSettingsScreenState();
}

class _AppScriptSettingsScreenState extends State<AppScriptSettingsScreen> {
  static const _urlKey = 'appscript_url';
  final _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _controller.text = prefs.getString(_urlKey) ?? '';
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveUrl() async {
    final url = _controller.text.trim();

    if (!url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL harus diawali dengan https://')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL Apps Script berhasil disimpan')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'URL Apps Script',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'https://script.google.com/macros/s/.../exec',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveUrl,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan URL'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
