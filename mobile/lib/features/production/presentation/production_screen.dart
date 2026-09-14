import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../sync/local_master_server.dart';
import '../../../sync/offline_store.dart';
import '../data/production_store.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  Map<String, dynamic> _snap = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _desk(const {'action': 'snapshot'});
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _produce(Map<String, dynamic> recipe) async {
    final batches = await _askBatches(recipe['name']?.toString() ?? 'Recette');
    if (batches == null) return;
    try {
      final snap = await _desk({
        'action': 'produce',
        'recipe_id': recipe['id'],
        'batches': batches,
      });
      if (!mounted) return;
      setState(() => _snap = snap);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$batches × ${recipe['name']} produit · matières premières − · produit fini +')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', '').replaceFirst('StockConflict: ', ''))),
      );
    }
  }

  Future<Map<String, dynamic>> _desk(Map<String, dynamic> action) async {
    final remote = LocalMasterServer.clientBaseUrl();
    if (remote != null) {
      http.Response? response;
      try {
        response = await http
            .post(
              Uri.parse('$remote/production/actions'),
              headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
              body: jsonEncode(action),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        response = null;
      }
      if (response != null) {
        final body = jsonDecode(response.body);
        final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
        if (response.statusCode != 200) {
          throw Exception(map['message']?.toString() ?? 'Maître local injoignable');
        }
        final data = map['data'] as Map<String, dynamic>? ?? map;
        final stock = data['stock'];
        if (stock is List) await OfflineStore.instance.applyAuthoritativeStock(stock);
        return data;
      }
    }
    if (action['action'] == 'produce') return ProductionStore.instance.produce(action);
    return ProductionStore.instance.snapshot();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = (_snap['recipes'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();
    final runs = (_snap['runs'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Production')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text('Recette → matières premières − → produit fini +'),
                    const SizedBox(height: 12),
                    if (recipes.isEmpty) const Text('Aucune recette.'),
                    for (final recipe in recipes) _recipeCard(recipe),
                    if (runs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Dernières productions'),
                      for (final run in runs)
                        ListTile(
                          dense: true,
                          title: Text('${run['batches']} × ${run['recipe_name']}'),
                          subtitle: Text(_runSummary(run)),
                        ),
                    ],
                  ],
                ),
    );
  }

  Widget _recipeCard(Map<String, dynamic> recipe) {
    final lines = (recipe['lines'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${recipe['name']}', style: Theme.of(context).textTheme.titleMedium),
            Text('Produit fini : ${recipe['finished_name']} · stock ${recipe['finished_on_hand'] ?? '—'}'),
            const SizedBox(height: 8),
            for (final line in lines)
              Text('${line['name']}  −${line['quantity']}  (stock ${line['quantity_on_hand'] ?? '—'})'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _produce(recipe),
              child: const Text('Produire'),
            ),
          ],
        ),
      ),
    );
  }

  String _runSummary(Map<String, dynamic> run) {
    final used = (run['ingredients'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((line) => '${line['name']} −${line['quantity']}')
        .join(', ');
    final finished = 'produit fini +${run['finished_quantity']}';
    return used.isEmpty ? finished : '$used · $finished';
  }

  Future<int?> _askBatches(String name) async {
    final controller = TextEditingController(text: '1');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Produire $name'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantité'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Produire'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value <= 0) return null;
    return value;
  }
}
