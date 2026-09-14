import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../sync/local_master_server.dart';
import '../data/notification_watch.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  static const _labels = {
    'low_stock': 'Stock faible',
    'expired': 'Produit expiré',
    'sync_failed': 'Sync échouée',
    'cash_open': 'Caisse ouverte',
    'credit_overdue': 'Crédit en retard',
    'order_pending': 'Commande en attente',
  };

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
      final items = await _fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<List<Map<String, dynamic>>> _fetch() async {
    final remote = LocalMasterServer.clientBaseUrl();
    if (remote != null) {
      http.Response? response;
      try {
        response = await http
            .post(
              Uri.parse('$remote/notifications/actions'),
              headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
              body: '{}',
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        response = null;
      }
      if (response != null && response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body is Map<String, dynamic> ? body['data'] : null;
        if (data is List) {
          return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
        }
      }
    }
    return NotificationWatch.instance.snapshot();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('Rien à signaler.'))
                  : ListView(
                      children: [
                        for (final item in _items)
                          ListTile(
                            title: Text(item['title']?.toString() ?? ''),
                            subtitle: Text(item['detail']?.toString() ?? ''),
                            trailing: Text(_labels[item['kind']] ?? item['kind'].toString()),
                          ),
                      ],
                    ),
    );
  }
}
