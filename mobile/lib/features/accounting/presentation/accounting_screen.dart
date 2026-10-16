import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/local_master_server.dart';
import '../data/ledger_store.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  Map<String, dynamic> _snap = const {};
  bool _loading = true;
  String? _error;
  String _open = 'profit';

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
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _run(Map<String, dynamic> action) async {
    try {
      final snap = await _desk(action);
      if (!mounted) return;
      setState(() => _snap = snap);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(_message(error)))));
    }
  }

  Future<Map<String, dynamic>> _desk(Map<String, dynamic> action) async {
    final remote = LocalMasterServer.clientBaseUrl();
    if (remote != null) {
      http.Response? response;
      try {
        response = await http
            .post(
              Uri.parse('$remote/accounting/actions'),
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
    return switch (action['action']) {
      'expense' => LedgerStore.instance.expense(action),
      'pay_payable' => LedgerStore.instance.payPayable(action),
      _ => LedgerStore.instance.snapshot(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final books = (_snap['books'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();
    final currency = TerminalConfigRepository.instance.config.currencyCode;
    String money(int amount) => MoneyFormatter.format(amount, currencyCode: currency);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Comptabilité')),
        actions: [
          IconButton(tooltip: tr('Dépense'), onPressed: () => _expense(), icon: const Icon(Icons.remove_circle_outline)),
          IconButton(tooltip: tr('Payer une dette'), onPressed: () => _pay(), icon: const Icon(Icons.payments_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(tr(_error!)))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(tr('Recettes, dépenses, créances, dettes, caisse, stock, profit.')),
                    const SizedBox(height: 12),
                    for (final book in books)
                      Card(
                        child: ExpansionTile(
                          initiallyExpanded: book['code'] == _open,
                          onExpansionChanged: (open) {
                            if (open) setState(() => _open = book['code'].toString());
                          },
                          title: Text(tr(book['label']?.toString() ?? '')),
                          trailing: Text(tr(money((book['balance'] as num?)?.toInt() ?? 0))),
                          children: [
                            if ((book['lines'] as List?)?.isEmpty ?? true)
                              ListTile(title: Text(tr('Aucune écriture.'))),
                            for (final line in (book['lines'] as List<dynamic>? ?? []).whereType<Map>())
                              ListTile(
                                dense: true,
                                title: Text(tr(line['memo']?.toString() ?? '')),
                                trailing: Text(tr(money((line['amount'] as num?)?.toInt() ?? 0))),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Future<void> _expense() async {
    final memo = TextEditingController();
    final amount = TextEditingController();
    var settlement = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('Dépense')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: memo, decoration: InputDecoration(labelText: tr('Libellé'))),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: tr('Montant')),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: settlement,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: 'cash', child: Text(tr('Payée en caisse'))),
                  DropdownMenuItem(value: 'payable', child: Text(tr('À payer (dette)'))),
                ],
                onChanged: (value) => setLocal(() => settlement = value ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Annuler'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Enregistrer'))),
          ],
        ),
      ),
    );
    final label = memo.text.trim();
    final minor = _minor(amount.text);
    memo.dispose();
    amount.dispose();
    if (ok != true) return;
    await _run({'action': 'expense', 'memo': label, 'amount': minor, 'settlement': settlement});
  }

  Future<void> _pay() async {
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Payer une dette')),
        content: TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('Montant')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Payer'))),
        ],
      ),
    );
    final minor = _minor(amount.text);
    amount.dispose();
    if (ok != true) return;
    await _run({'action': 'pay_payable', 'amount': minor});
  }

  int _minor(String input) {
    final value = double.tryParse(input.trim().replaceAll(',', '.')) ?? 0;
    return (value * 100).round();
  }

  String _message(Object error) => error.toString().replaceFirst('Exception: ', '');
}
