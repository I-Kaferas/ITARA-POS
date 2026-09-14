import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/local_master_server.dart';
import '../data/service_desk_store.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<Map<String, dynamic>> _docs = [];
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
        _docs = _asDocs(snap);
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

  Future<void> _run(Map<String, dynamic> action) async {
    try {
      final snap = await _desk(action);
      if (!mounted) return;
      setState(() => _docs = _asDocs(snap));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<Map<String, dynamic>> _desk(Map<String, dynamic> action) async {
    final remote = LocalMasterServer.clientBaseUrl();
    if (remote != null) {
      try {
        final response = await http
            .post(
              Uri.parse('$remote/services/actions'),
              headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
              body: jsonEncode(action),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          return body['data'] as Map<String, dynamic>? ?? body;
        }
      } catch (_) {}
    }
    if (action['action'] == 'snapshot') return ServiceDeskStore.instance.snapshot();
    return ServiceDeskStore.instance.apply(action);
  }

  List<Map<String, dynamic>> _asDocs(Map<String, dynamic> snap) {
    return (snap['docs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final offerings = _docs.where((doc) => doc['kind'] == 'service_offering').toList();
    final employees = _docs.where((doc) => doc['kind'] == 'service_employee').toList();
    final jobs = _docs.where((doc) => doc['kind'] == 'service_job').toList();
    final money = MoneyFormatter.format;
    final currency = TerminalConfigRepository.instance.config.currencyCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: offerings.isEmpty ? null : () => _book(offerings),
        icon: const Icon(Icons.add),
        label: const Text('Rendez-vous'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text('Service → rendez-vous → employé → réalisation → paiement'),
                    const SizedBox(height: 8),
                    Text(offerings.map((item) => '${item['name']} · ${_category(item['category']?.toString())}').join(' · ')),
                    const SizedBox(height: 12),
                    if (jobs.isEmpty) const Text('Aucun rendez-vous.'),
                    for (final job in jobs)
                      Card(
                        child: ListTile(
                          title: Text('${job['service_name']} · ${job['customer_name']}'),
                          subtitle: Text(
                            '${_step(job['status']?.toString())}'
                            '${(job['employee_name']?.toString() ?? '').isEmpty ? '' : ' · ${job['employee_name']}'}'
                            ' · ${money((job['price'] as num?)?.toInt() ?? 0, currencyCode: currency)}',
                          ),
                          trailing: _action(job, employees),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget? _action(Map<String, dynamic> job, List<Map<String, dynamic>> employees) {
    return switch (job['status']) {
      'booked' => FilledButton(
          onPressed: () => _assign(job, employees),
          child: const Text('Employé'),
        ),
      'assigned' => FilledButton(
          onPressed: () => _complete(job),
          child: const Text('Terminer'),
        ),
      'completed' => FilledButton(
          onPressed: () => _run({'action': 'pay', 'job_id': job['id']}),
          child: const Text('Payer'),
        ),
      _ => Text(job['reference']?.toString() ?? 'Payé'),
    };
  }

  Future<void> _book(List<Map<String, dynamic>> offerings) async {
    final name = TextEditingController();
    var serviceId = offerings.first['id'].toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rendez-vous'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: serviceId,
              items: [
                for (final item in offerings)
                  DropdownMenuItem(value: item['id'].toString(), child: Text('${item['name']} · ${_category(item['category']?.toString())}')),
              ],
              onChanged: (value) => serviceId = value ?? serviceId,
            ),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Client')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Créer')),
        ],
      ),
    );
    final customer = name.text.trim();
    name.dispose();
    if (ok != true || customer.isEmpty) return;
    await _run({'action': 'book', 'service_id': serviceId, 'customer_name': customer});
  }

  Future<void> _assign(Map<String, dynamic> job, List<Map<String, dynamic>> employees) async {
    final nameCtrl = TextEditingController();
    var employeeId = employees.isEmpty ? '' : employees.first['id'].toString();
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Employé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (employees.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: employeeId,
                items: [
                  for (final item in employees)
                    DropdownMenuItem(value: item['id'].toString(), child: Text(item['name']?.toString() ?? 'Employé')),
                ],
                onChanged: (value) => employeeId = value ?? employeeId,
              ),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nouvel employé')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final created = nameCtrl.text.trim();
              if (created.isNotEmpty) {
                Navigator.pop(context, {
                  'id': 'emp-${DateTime.now().millisecondsSinceEpoch}',
                  'name': created,
                  'create': true,
                });
                return;
              }
              Map<String, dynamic>? current;
              for (final item in employees) {
                if (item['id'] == employeeId) current = item;
              }
              if (current == null) return;
              Navigator.pop(context, current);
            },
            child: const Text('Assigner'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (picked == null) return;
    if (picked['create'] == true) {
      await _run({'action': 'add_employee', 'id': picked['id'], 'name': picked['name']});
    }
    await _run({
      'action': 'assign',
      'job_id': job['id'],
      'employee_id': picked['id'],
      'employee_name': picked['name'],
    });
  }

  Future<void> _complete(Map<String, dynamic> job) async {
    final notes = TextEditingController(text: 'Terminé');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réalisation'),
        content: TextField(controller: notes, decoration: const InputDecoration(labelText: 'Note')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Terminer')),
        ],
      ),
    );
    final text = notes.text.trim();
    notes.dispose();
    if (ok != true) return;
    await _run({'action': 'complete', 'job_id': job['id'], 'notes': text.isEmpty ? 'Terminé' : text});
  }
}

String _category(String? value) => switch (value) {
      'salon' => 'Salon',
      'garage' => 'Garage',
      'repair' => 'Réparation',
      'maintenance' => 'Maintenance',
      _ => value ?? 'Service',
    };

String _step(String? status) => switch (status) {
      'booked' => 'Rendez-vous',
      'assigned' => 'Employé',
      'completed' => 'Réalisé',
      'paid' => 'Payé',
      _ => status ?? '',
    };
