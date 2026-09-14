import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/local_master_server.dart';
import '../../../sync/offline_store.dart';
import '../../pos/domain/pos_models.dart';
import '../data/customer_account_store.dart';

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  final _search = TextEditingController();
  List<PosCustomer> _customers = [];
  Map<String, dynamic>? _account;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final rows = await OfflineStore.instance.searchCustomers(_search.text.trim());
    if (!mounted) return;
    setState(() => _customers = rows);
  }

  Future<void> _open(PosCustomer customer) async {
    try {
      final account = await _desk({'action': 'account', 'customer_id': customer.id});
      if (!mounted) return;
      setState(() {
        _account = account;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
    }
  }

  Future<void> _pay() async {
    final account = _account;
    if (account == null) return;
    final amount = await _askAmount('Paiement');
    if (amount == null) return;
    await _run({'action': 'pay', 'customer_id': account['customer_id'], 'amount': amount});
  }

  Future<void> _redeem() async {
    final account = _account;
    if (account == null) return;
    final points = await _askPoints();
    if (points == null) return;
    await _run({'action': 'redeem', 'customer_id': account['customer_id'], 'points': points});
  }

  Future<void> _run(Map<String, dynamic> action) async {
    try {
      final account = await _desk(action);
      if (!mounted) return;
      setState(() {
        _account = account;
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
              Uri.parse('$remote/customer-accounts/actions'),
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
      'pay' => CustomerAccountStore.instance.pay(action['customer_id'].toString(), (action['amount'] as num).toInt()),
      'redeem' => CustomerAccountStore.instance.redeem(action['customer_id'].toString(), (action['points'] as num).toInt()),
      'post_sale' => CustomerAccountStore.instance.postSale(
          customerId: action['customer_id'].toString(),
          saleId: action['sale_id'].toString(),
          total: (action['total'] as num?)?.toInt() ?? 0,
          outstanding: (action['outstanding'] as num?)?.toInt() ?? 0,
          payments: (action['payments'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList(),
          reference: action['reference']?.toString(),
        ),
      _ => CustomerAccountStore.instance.account(action['customer_id'].toString()),
    };
  }

  @override
  Widget build(BuildContext context) {
    final currency = TerminalConfigRepository.instance.config.currencyCode;
    String money(int amount) => MoneyFormatter.format(amount, currencyCode: currency);
    final account = _account;
    final lines = (account?['lines'] as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Client')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Achat → points → récompense. Crédit : vente +, paiement −.'),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            decoration: const InputDecoration(labelText: 'Client'),
            onSubmitted: (_) => _find(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _find, child: const Text('Chercher')),
          ),
          for (final customer in _customers)
            ListTile(
              title: Text(customer.displayLabel),
              onTap: () => _open(customer),
            ),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (account != null) ...[
            const Divider(),
            Text(account['customer_name']?.toString() ?? '', style: Theme.of(context).textTheme.titleMedium),
            Text('Solde initial 0 · solde ${money((account['balance'] as num?)?.toInt() ?? 0)}'),
            Text('Points ${account['points'] ?? 0} · ${account['rule']}'),
            Text(account['reward']?.toString() ?? ''),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(onPressed: _pay, child: const Text('Paiement')),
                FilledButton(onPressed: _redeem, child: const Text('Récompense')),
              ],
            ),
            if (lines.isEmpty) const Text('Aucun mouvement. Le solde reste 0.'),
            for (final line in lines)
              ListTile(
                dense: true,
                title: Text(line['memo']?.toString() ?? ''),
                subtitle: Text('Solde ${money((line['balance'] as num?)?.toInt() ?? 0)}'),
                trailing: Text(_signed(line, money)),
              ),
          ],
        ],
      ),
    );
  }

  String _signed(Map<String, dynamic> line, String Function(int) money) {
    if (line['type'] == 'points') return '+${line['points']} pt';
    final amount = (line['amount'] as num?)?.toInt() ?? 0;
    final text = money(amount.abs());
    return amount < 0 ? '-$text' : '+$text';
  }

  Future<int?> _askAmount(String title) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Montant'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Valider')),
        ],
      ),
    );
    final minor = ((double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0) * 100).round();
    controller.dispose();
    if (ok != true || minor <= 0) return null;
    return minor;
  }

  Future<int?> _askPoints() async {
    final controller = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Récompense'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Points'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Utiliser')),
        ],
      ),
    );
    final points = int.tryParse(controller.text.trim()) ?? 0;
    controller.dispose();
    if (ok != true || points <= 0) return null;
    return points;
  }

  String _message(Object error) => error.toString().replaceFirst('Exception: ', '');
}
