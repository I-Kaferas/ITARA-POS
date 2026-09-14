import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/local_master_server.dart';
import '../data/expense_desk_store.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  Map<String, dynamic> _snap = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final categories = (_snap['categories'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (categories.isEmpty) return;
    final description = TextEditingController();
    final amount = TextEditingController();
    var category = categories.first['code'].toString();
    var linkSession = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Dépense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: category,
                isExpanded: true,
                items: [
                  for (final item in categories)
                    DropdownMenuItem(value: item['code'].toString(), child: Text(item['name'].toString())),
                ],
                onChanged: (value) => setLocal(() => category = value ?? category),
              ),
              TextField(controller: description, decoration: const InputDecoration(labelText: 'Libellé')),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lier à la caisse ouverte'),
                value: linkSession,
                onChanged: (value) => setLocal(() => linkSession = value ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    final label = description.text.trim();
    final minor = ((double.tryParse(amount.text.trim().replaceAll(',', '.')) ?? 0) * 100).round();
    description.dispose();
    amount.dispose();
    if (ok != true) return;
    try {
      final snap = await _desk({
        'action': 'record',
        'category': category,
        'description': label,
        'amount': minor,
        'link_session': linkSession,
      });
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
    }
  }

  Future<Map<String, dynamic>> _desk(Map<String, dynamic> action) async {
    final remote = LocalMasterServer.clientBaseUrl();
    if (remote != null) {
      http.Response? response;
      try {
        response = await http
            .post(
              Uri.parse('$remote/expenses/actions'),
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
        return map['data'] as Map<String, dynamic>? ?? map;
      }
    }
    if (action['action'] == 'record') return ExpenseDeskStore.instance.record(action);
    return ExpenseDeskStore.instance.snapshot();
  }

  @override
  Widget build(BuildContext context) {
    final currency = TerminalConfigRepository.instance.config.currencyCode;
    String money(int amount) => MoneyFormatter.format(amount, currencyCode: currency);
    final contextInfo = _snap['context'] as Map<String, dynamic>? ?? {};
    final expenses = (_snap['expenses'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dépenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Dépense'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('Transport, électricité, loyer, salaire, achat urgent, entretien.'),
                Text('Succursale ${contextInfo['branch'] ?? '—'} · ${contextInfo['user'] ?? '—'}'),
                Text(
                  (contextInfo['cash_session_id']?.toString().isNotEmpty == true)
                      ? 'Caisse ouverte'
                      : 'Aucune session de caisse',
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                if (expenses.isEmpty) const Text('Aucune dépense.'),
                for (final row in expenses)
                  Card(
                    child: ListTile(
                      title: Text('${row['category_name']} · ${row['description']}'),
                      subtitle: Text('${row['branch']} · ${row['user_name']} · ${row['cash_session_id']?.toString().isNotEmpty == true ? 'Caisse' : 'Hors caisse'}'),
                      trailing: Text(money((row['amount'] as num?)?.toInt() ?? 0)),
                    ),
                  ),
              ],
            ),
    );
  }

  String _message(Object error) => error.toString().replaceFirst('Exception: ', '');
}
