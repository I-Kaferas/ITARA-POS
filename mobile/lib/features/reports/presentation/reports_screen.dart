import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/local_master_server.dart';
import '../data/reports_store.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _periods = [
    ('day', 'Jour'),
    ('week', 'Semaine'),
    ('month', 'Mois'),
    ('year', 'Année'),
  ];

  String _period = 'day';
  Map<String, dynamic> _report = const {};
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
      final report = await _fetch(_period);
      if (!mounted) return;
      setState(() {
        _report = report;
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

  Future<Map<String, dynamic>> _fetch(String period) async {
    final remote = LocalMasterServer.clientBaseUrl();
    if (remote != null) {
      http.Response? response;
      try {
        response = await http
            .post(
              Uri.parse('$remote/reports/actions'),
              headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
              body: jsonEncode({'period': period}),
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
    return ReportsStore.instance.build(period);
  }

  @override
  Widget build(BuildContext context) {
    final currency = TerminalConfigRepository.instance.config.currencyCode;
    String money(int amount) => MoneyFormatter.format(amount, currencyCode: currency);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rapports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ventes'),
              Tab(text: 'Stock'),
              Tab(text: 'Finance'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final period in _periods)
                    ChoiceChip(
                      label: Text(period.$2),
                      selected: _period == period.$1,
                      onSelected: (_) {
                        setState(() => _period = period.$1);
                        _load();
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          children: [
                            _sales(money),
                            _stock(money),
                            _finance(money),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sales(String Function(int) money) {
    final sales = _report['sales'] as Map<String, dynamic>? ?? {};
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('${sales['count'] ?? 0} ventes · ${money((sales['total'] as num?)?.toInt() ?? 0)}'),
        _section('Produit', sales['by_product'], money),
        _section('Catégorie', sales['by_category'], money),
        _section('Caissier', sales['by_cashier'], money),
        _section('Magasin', sales['by_store'], money),
      ],
    );
  }

  Widget _stock(String Function(int) money) {
    final stock = _report['stock'] as Map<String, dynamic>? ?? {};
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Valorisation ${money((stock['valuation'] as num?)?.toInt() ?? 0)}'),
        _section('Stock actuel', stock['current'], money, showQty: true),
        _section('Stock faible', stock['low'], money),
        _section('Mouvements', stock['movements'], money, showQty: true),
        Text('Pertes ${money((stock['losses_value'] as num?)?.toInt() ?? 0)}'),
        _section('Pertes', stock['losses'], money, showQty: true),
        _section('Expiration', stock['expiration'], money),
      ],
    );
  }

  Widget _finance(String Function(int) money) {
    final finance = _report['finance'] as Map<String, dynamic>? ?? {};
    final rows = [
      ('CA', finance['revenue']),
      ('Dépenses', finance['expenses']),
      ('Marge', finance['margin']),
      ('Bénéfice', finance['profit']),
      ('Crédit', finance['credit']),
      ('Dettes', finance['debts']),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in rows)
          ListTile(
            title: Text(row.$1),
            trailing: Text(money((row.$2 as num?)?.toInt() ?? 0)),
          ),
      ],
    );
  }

  Widget _section(String title, Object? rows, String Function(int) money, {bool showQty = false}) {
    final lines = (rows as List<dynamic>? ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (lines.isEmpty) const Text('Aucune donnée.'),
        for (final line in lines)
          ListTile(
            dense: true,
            title: Text(line['label']?.toString() ?? ''),
            subtitle: line['detail'] != null
                ? Text(line['detail'].toString())
                : (showQty ? Text('Qté ${line['quantity'] ?? 0}') : null),
            trailing: line['amount'] == null ? null : Text(money((line['amount'] as num?)?.toInt() ?? 0)),
          ),
      ],
    );
  }
}
