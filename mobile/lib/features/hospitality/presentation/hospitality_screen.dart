import 'package:flutter/material.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../core/utils/money_formatter.dart';
import '../data/hospitality_api.dart';

class HospitalityScreen extends StatefulWidget {
  const HospitalityScreen({super.key});

  @override
  State<HospitalityScreen> createState() => _HospitalityScreenState();
}

class _HospitalityScreenState extends State<HospitalityScreen> {
  final _api = HospitalityApi();
  List<Map<String, dynamic>> _docs = [];
  String _section = 'restaurant';
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
      final snap = await _api.snapshot();
      final docs = (snap['docs'] as List<dynamic>? ?? []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() {
        _docs = docs;
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
      final snap = await _api.apply(action);
      final docs = (snap['docs'] as List<dynamic>? ?? []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() => _docs = docs);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  List<Map<String, dynamic>> _kind(String kind) => _docs.where((doc) => doc['kind'] == kind).toList();

  String _money(int amount) => MoneyFormatter.format(amount, currencyCode: TerminalConfigRepository.instance.config.currencyCode);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant & hôtel'),
        actions: [
          IconButton(onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'restaurant', label: Text('Tables'), icon: Icon(Icons.table_restaurant)),
                          ButtonSegment(value: 'kitchen', label: Text('KDS'), icon: Icon(Icons.soup_kitchen)),
                          ButtonSegment(value: 'hotel', label: Text('Hôtel'), icon: Icon(Icons.hotel)),
                        ],
                        selected: {_section},
                        onSelectionChanged: (value) => setState(() => _section = value.first),
                      ),
                    ),
                    Expanded(
                      child: switch (_section) {
                        'kitchen' => _KitchenBoard(tickets: _kind('ticket'), onAdvance: _run),
                        'hotel' => _HotelBoard(
                            rooms: _kind('room'),
                            types: _kind('room_type'),
                            reservations: _kind('reservation'),
                            folios: _kind('folio'),
                            money: _money,
                            onAction: _run,
                          ),
                        _ => _FloorBoard(
                            zones: _kind('zone'),
                            tables: _kind('table'),
                            servers: _kind('server'),
                            orders: _kind('order'),
                            rooms: _kind('room').where((room) => room['status'] == 'occupied').toList(),
                            money: _money,
                            onAction: _run,
                          ),
                      },
                    ),
                  ],
                ),
    );
  }
}

class _FloorBoard extends StatelessWidget {
  const _FloorBoard({
    required this.zones,
    required this.tables,
    required this.servers,
    required this.orders,
    required this.rooms,
    required this.money,
    required this.onAction,
  });

  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> servers;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> rooms;
  final String Function(int amount) money;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _addServer(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Ajouter un serveur'),
          ),
        ),
        const SizedBox(height: 12),
        for (final zone in zones) ...[
          Text(zone['name']?.toString() ?? 'Zone', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final table in tables.where((item) => item['zone_id'] == zone['id']))
                _TableCard(
                  table: table,
                  order: orders.cast<Map<String, dynamic>?>().firstWhere(
                    (order) => order?['id'] == table['order_id'],
                    orElse: () => null,
                  ),
                  serverName: _serverName(table),
                  onTap: () => _openTable(context, table),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  String? _serverName(Map<String, dynamic> table) {
    final order = orders.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == table['order_id'],
      orElse: () => null,
    );
    final named = order?['server_name']?.toString() ?? '';
    if (named.isNotEmpty) return named;
    final serverId = order?['server_id']?.toString() ?? '';
    final server = servers.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == serverId,
      orElse: () => null,
    );
    return server?['name']?.toString();
  }

  Future<void> _addServer(BuildContext context) async {
    final name = await _askName(context, 'Nouveau serveur');
    if (name == null || name.isEmpty) return;
    await onAction({'action': 'add_server', 'name': name});
  }

  Future<void> _openTable(BuildContext context, Map<String, dynamic> table) async {
    if (table['status'] != 'occupied') {
      final server = await _pickServer(context);
      if (server == null) return;
      await onAction({
        'action': 'open_order',
        'table_id': table['id'],
        'server_id': server['id'],
        'server_name': server['name'],
      });
      return;
    }
    final order = orders.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == table['order_id'],
      orElse: () => null,
    );
    if (order == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OrderSheet(
        order: order,
        rooms: rooms,
        money: money,
        onAction: onAction,
      ),
    );
  }

  Future<Map<String, dynamic>?> _pickServer(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Serveur de la table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final server in servers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(server['name']?.toString() ?? 'Serveur'),
                onTap: () => Navigator.pop(context, server),
              ),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nouveau serveur'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, {'id': 'server-${DateTime.now().millisecondsSinceEpoch}', 'name': name, 'create': true});
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (picked == null) return null;
    if (picked['create'] == true) {
      await onAction({'action': 'add_server', 'id': picked['id'], 'name': picked['name']});
    }
    return picked;
  }

  Future<String?> _askName(BuildContext context, String title) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nom')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.order,
    required this.serverName,
    required this.onTap,
  });

  final Map<String, dynamic> table;
  final Map<String, dynamic>? order;
  final String? serverName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final occupied = table['status'] == 'occupied';
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: occupied ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: occupied ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(table['label']?.toString() ?? 'Table', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(occupied ? _orderStep(order?['status']?.toString()) : 'libre'),
            if (occupied && (serverName ?? '').isNotEmpty)
              Text(serverName!, style: const TextStyle(fontSize: 12)),
            Text('${table['seats']} places', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _OrderSheet extends StatefulWidget {
  const _OrderSheet({
    required this.order,
    required this.rooms,
    required this.money,
    required this.onAction,
  });

  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> rooms;
  final String Function(int amount) money;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  String _course = 'plat';
  final _selected = <String>{};

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _lines =>
      (widget.order['lines'] as List<dynamic>? ?? []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();

  List<Map<String, dynamic>> get _checks =>
      (widget.order['checks'] as List<dynamic>? ?? []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Table ${widget.order['table_label']} · ${_orderStep(widget.order['status']?.toString())}'
              '${(widget.order['server_name']?.toString() ?? '').isEmpty ? '' : ' · ${widget.order['server_name']}'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Table → commande → cuisine → préparation → service → paiement'),
            const SizedBox(height: 12),
            for (final line in _lines)
              CheckboxListTile(
                dense: true,
                value: _selected.contains(line['id']),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selected.add(line['id'].toString());
                    } else {
                      _selected.remove(line['id']);
                    }
                  });
                },
                title: Text('${line['quantity']} × ${line['name']} · ${line['course']}'),
                subtitle: Text(widget.money(((line['unit_price'] as num?)?.toInt() ?? 0) * ((line['quantity'] as num?)?.toInt() ?? 0))),
              ),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Article')),
            TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix')),
            DropdownButton<String>(
              value: _course,
              items: const [
                DropdownMenuItem(value: 'entree', child: Text('Entrée')),
                DropdownMenuItem(value: 'plat', child: Text('Plat')),
                DropdownMenuItem(value: 'dessert', child: Text('Dessert')),
                DropdownMenuItem(value: 'boisson', child: Text('Boisson')),
              ],
              onChanged: (value) => setState(() => _course = value ?? 'plat'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () async {
                    final price = ((double.tryParse(_price.text.replaceAll(',', '.')) ?? 0) * 100).round();
                    await widget.onAction({
                      'action': 'add_line',
                      'order_id': widget.order['id'],
                      'name': _name.text.trim(),
                      'unit_price': price,
                      'quantity': 1,
                      'course': _course,
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Ajouter'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await widget.onAction({'action': 'send_course', 'order_id': widget.order['id'], 'course': _course});
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Envoyer cuisine'),
                ),
                OutlinedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () async {
                          await widget.onAction({
                            'action': 'split_lines',
                            'order_id': widget.order['id'],
                            'line_ids': _selected.toList(),
                          });
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('Séparer l’addition'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final check in _checks.where((item) => item['status'] == 'open'))
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () async {
                      await widget.onAction({'action': 'pay_check', 'order_id': widget.order['id'], 'check_id': check['id']});
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text('Payer ${check['label']}'),
                  ),
                  for (final room in widget.rooms)
                    OutlinedButton(
                      onPressed: () async {
                        await widget.onAction({
                          'action': 'charge_room',
                          'order_id': widget.order['id'],
                          'check_id': check['id'],
                          'room_id': room['id'],
                        });
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text('Folio ${room['number']}'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _orderStep(String? status) => switch (status) {
      'open' => 'Commande',
      'kitchen' => 'Cuisine',
      'preparing' => 'Préparation',
      'ready' => 'Service',
      'served' => 'Paiement',
      'paid' => 'Payée',
      _ => status ?? 'occupée',
    };

class _KitchenBoard extends StatelessWidget {
  const _KitchenBoard({required this.tickets, required this.onAdvance});

  final List<Map<String, dynamic>> tickets;
  final Future<void> Function(Map<String, dynamic> action) onAdvance;

  @override
  Widget build(BuildContext context) {
    final open = tickets.where((ticket) => ticket['status'] != 'served').toList();
    const columns = [
      ('sent', 'Cuisine'),
      ('preparing', 'Préparation'),
      ('ready', 'Service'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final board = columns
            .map((column) => _KdsColumn(
                  title: column.$2,
                  tickets: open.where((ticket) => ticket['status'] == column.$1).toList(),
                  onAdvance: onAdvance,
                  scroll: wide,
                ))
            .toList();
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final column in board) Expanded(child: column),
            ],
          );
        }
        return ListView(padding: const EdgeInsets.all(12), children: board);
      },
    );
  }
}

class _KdsColumn extends StatelessWidget {
  const _KdsColumn({
    required this.title,
    required this.tickets,
    required this.onAdvance,
    this.scroll = false,
  });

  final String title;
  final List<Map<String, dynamic>> tickets;
  final Future<void> Function(Map<String, dynamic> action) onAdvance;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Text('$title · ${tickets.length}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (tickets.isEmpty)
        const Text('Aucun bon')
      else
        for (final ticket in tickets) _KdsCard(ticket: ticket, onAdvance: onAdvance),
    ];
    if (!scroll) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
    }
    return ListView(padding: const EdgeInsets.all(8), children: children);
  }
}

class _KdsCard extends StatelessWidget {
  const _KdsCard({required this.ticket, required this.onAdvance});

  final Map<String, dynamic> ticket;
  final Future<void> Function(Map<String, dynamic> action) onAdvance;

  @override
  Widget build(BuildContext context) {
    final next = switch (ticket['status']) {
      'sent' => 'preparing',
      'preparing' => 'ready',
      'ready' => 'served',
      _ => null,
    };
    final label = switch (next) {
      'preparing' => 'Préparation',
      'ready' => 'Prêt',
      'served' => 'Servi',
      _ => '',
    };
    final lines = (ticket['lines'] as List<dynamic>? ?? []).whereType<Map>().toList();
    final server = ticket['server_name']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ticket['table_label']} · ${ticket['course']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (server.isNotEmpty) Text(server),
            const SizedBox(height: 4),
            Text(lines.map((line) => '${line['quantity']} ${line['name']}').join('\n')),
            if (next != null) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => onAdvance({'action': 'set_ticket_status', 'ticket_id': ticket['id'], 'status': next}),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HotelBoard extends StatelessWidget {
  const _HotelBoard({
    required this.rooms,
    required this.types,
    required this.reservations,
    required this.folios,
    required this.money,
    required this.onAction,
  });

  final List<Map<String, dynamic>> rooms;
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> reservations;
  final List<Map<String, dynamic>> folios;
  final String Function(int amount) money;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  Widget build(BuildContext context) {
    final invoices = folios.where((folio) => folio['status'] == 'closed').toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Types: ${types.map((type) => '${type['name']} ${money((type['rate'] as num?)?.toInt() ?? 0)}').join(' · ')}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (final room in rooms) _roomCard(context, room),
        if (invoices.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Factures hôtel', style: Theme.of(context).textTheme.titleMedium),
          for (final folio in invoices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Chambre ${folio['room_number']} · ${folio['guest_name'] ?? 'Client'}'),
              subtitle: Text(folio['reference']?.toString() ?? 'Sans encaissement'),
            ),
        ],
      ],
    );
  }

  Widget _roomCard(BuildContext context, Map<String, dynamic> room) {
    final folio = _openFolio(room);
    final lines = (folio?['lines'] as List<dynamic>? ?? []).whereType<Map>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chambre ${room['number']} · ${_roomStatus(room['status']?.toString())}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(_subtitle(room)),
            for (final line in lines)
              Text(
                '${_lineKind(line['kind']?.toString())} · ${line['description']} · ${money((line['amount'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (room['status'] == 'vacant') ...[
                  FilledButton(
                    onPressed: () => _book(context, room, arrive: false),
                    child: const Text('Réserver'),
                  ),
                  OutlinedButton(
                    onPressed: () => _book(context, room, arrive: true),
                    child: const Text('Check-in'),
                  ),
                ],
                if (room['status'] == 'reserved')
                  FilledButton(
                    onPressed: () {
                      final reservation = _reservation(room['id']?.toString(), 'reserved');
                      if (reservation == null) return;
                      onAction({'action': 'check_in', 'reservation_id': reservation['id']});
                    },
                    child: const Text('Check-in'),
                  ),
                if (room['status'] == 'occupied') ...[
                  OutlinedButton(
                    onPressed: () => _postConsumption(context, room, 'minibar', 'Minibar'),
                    child: const Text('Minibar'),
                  ),
                  OutlinedButton(
                    onPressed: () => _postConsumption(context, room, 'room_service', 'Room service'),
                    child: const Text('Room service'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final reservation = _reservation(room['id']?.toString(), 'checked_in');
                      if (reservation == null) return;
                      onAction({'action': 'check_out', 'reservation_id': reservation['id']});
                    },
                    child: const Text('Check-out'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _reservation(String? roomId, String status) {
    return reservations.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['room_id'] == roomId && item?['status'] == status,
      orElse: () => null,
    );
  }

  Future<void> _book(BuildContext context, Map<String, dynamic> room, {required bool arrive}) async {
    final stay = await _askStay(context, room['number']?.toString() ?? '', arrive: arrive);
    if (stay == null) return;
    await onAction({
      'action': arrive ? 'arrive' : 'create_reservation',
      'room_id': room['id'],
      'guest_name': stay.$1,
      'nights': stay.$2,
    });
  }

  Future<void> _postConsumption(BuildContext context, Map<String, dynamic> room, String kind, String label) async {
    final posted = await _askConsumption(context, label);
    if (posted == null) return;
    await onAction({
      'action': 'post_folio',
      'room_id': room['id'],
      'kind': kind,
      'description': posted.$1,
      'amount': posted.$2,
    });
  }

  Future<(String, int)?> _askStay(BuildContext context, String number, {required bool arrive}) async {
    final nameCtrl = TextEditingController();
    final nightsCtrl = TextEditingController(text: '1');
    final stay = await showDialog<(String, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(arrive ? 'Check-in chambre $number' : 'Réservation chambre $number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Client')),
            TextField(
              controller: nightsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nuits'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final nights = int.tryParse(nightsCtrl.text.trim()) ?? 1;
              Navigator.pop(context, (name, nights < 1 ? 1 : nights));
            },
            child: Text(arrive ? 'Check-in' : 'Réserver'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    nightsCtrl.dispose();
    return stay;
  }

  Future<(String, int)?> _askConsumption(BuildContext context, String label) async {
    final description = TextEditingController(text: label);
    final amount = TextEditingController();
    final posted = await showDialog<(String, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Libellé')),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final minor = ((double.tryParse(amount.text.replaceAll(',', '.')) ?? 0) * 100).round();
              if (minor <= 0) return;
              Navigator.pop(context, (description.text.trim().isEmpty ? label : description.text.trim(), minor));
            },
            child: const Text('Ajouter au folio'),
          ),
        ],
      ),
    );
    description.dispose();
    amount.dispose();
    return posted;
  }

  Map<String, dynamic>? _openFolio(Map<String, dynamic> room) {
    return folios.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == room['folio_id'] && item?['status'] == 'open',
      orElse: () => null,
    );
  }

  String _subtitle(Map<String, dynamic> room) {
    final guest = room['guest_name']?.toString() ?? '';
    final folio = _openFolio(room);
    if (folio == null) {
      final invoice = room['last_invoice']?.toString() ?? '';
      if (invoice.isNotEmpty) return 'Dernière facture $invoice';
      return guest.isEmpty ? 'Libre' : guest;
    }
    final lines = (folio['lines'] as List<dynamic>? ?? []).whereType<Map>();
    final total = lines.fold<int>(0, (sum, line) => sum + ((line['amount'] as num?)?.toInt() ?? 0));
    return '${folio['guest_name'] ?? guest} · folio ${money(total)}';
  }

  String _roomStatus(String? status) => switch (status) {
        'vacant' => 'Libre',
        'reserved' => 'Réservée',
        'occupied' => 'Occupée',
        _ => status ?? '',
      };

  String _lineKind(String? kind) => switch (kind) {
        'stay' => 'Hébergement',
        'restaurant' => 'Restaurant',
        'minibar' => 'Minibar',
        'room_service' => 'Room service',
        _ => 'Consommation',
      };
}
