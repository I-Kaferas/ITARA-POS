import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/offline_store.dart';
import '../../pos/domain/pos_models.dart';

class HospitalityStore {
  HospitalityStore._();

  static final HospitalityStore instance = HospitalityStore._();

  Future<Database> get _db => LocalDatabase.instance.database;

  Future<Map<String, dynamic>> snapshot() async {
    await _seed();
    final db = await _db;
    final rows = await db.query('hospitality_docs', orderBy: 'kind ASC, updated_at ASC');
    final docs = rows.map((row) {
      final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      return {
        ...json,
        'id': row['id'],
        'kind': row['kind'],
        'status': row['status'],
      };
    }).toList();
    return {'docs': docs};
  }

  Future<Map<String, dynamic>> apply(Map<String, dynamic> action) async {
    await _seed();
    final name = action['action']?.toString() ?? '';
    switch (name) {
      case 'add_server':
        await _addServer(action);
      case 'open_order':
        await _openOrder(action);
      case 'add_line':
        await _addLine(action);
      case 'send_course':
        await _sendCourse(action);
      case 'set_ticket_status':
        await _setTicketStatus(action);
      case 'split_lines':
        await _splitLines(action);
      case 'pay_check':
        await _payCheck(action);
      case 'charge_room':
        await _chargeRoom(action);
      case 'create_reservation':
        await _createReservation(action);
      case 'arrive':
        await _arrive(action);
      case 'check_in':
        await _checkIn(action);
      case 'check_out':
        await _checkOut(action);
      case 'post_folio':
        await _postFolio(action);
      default:
        throw Exception('Action inconnue');
    }
    return snapshot();
  }

  Future<void> _seed() async {
    final db = await _db;
    final existing = await db.query('hospitality_docs', limit: 1);
    if (existing.isNotEmpty) {
      final servers = await db.query('hospitality_docs', where: "kind = 'server'", limit: 1);
      if (servers.isEmpty) {
        final cashier = TerminalConfigRepository.instance.config.cashierName;
        await _save('server', 'server-1', {'name': cashier.trim().isEmpty ? 'Service' : cashier.trim()});
      }
      return;
    }
    final now = DateTime.now().toIso8601String();
    final cashier = TerminalConfigRepository.instance.config.cashierName;
    Future<void> put(String kind, String id, Map<String, dynamic> json, {String? parentId, String? status}) {
      return db.insert('hospitality_docs', {
        'id': id,
        'kind': kind,
        'parent_id': parentId,
        'status': status ?? json['status'],
        'json': jsonEncode({...json, 'id': id}),
        'updated_at': now,
      });
    }

    await put('zone', 'zone-salle', {'name': 'Salle'});
    await put('zone', 'zone-terrasse', {'name': 'Terrasse'});
    for (var i = 1; i <= 4; i++) {
      await put('table', 'table-$i', {'label': 'T$i', 'seats': 4, 'zone_id': 'zone-salle', 'status': 'free'}, parentId: 'zone-salle', status: 'free');
    }
    for (var i = 5; i <= 6; i++) {
      await put('table', 'table-$i', {'label': 'T$i', 'seats': 2, 'zone_id': 'zone-terrasse', 'status': 'free'}, parentId: 'zone-terrasse', status: 'free');
    }
    await put('server', 'server-1', {'name': cashier.trim().isEmpty ? 'Service' : cashier.trim()});
    await put('server', 'server-2', {'name': 'Serveur salle'});
    await put('room_type', 'type-standard', {'name': 'Standard', 'rate': 8000000});
    await put('room_type', 'type-suite', {'name': 'Suite', 'rate': 15000000});
    await put('room', 'room-201', {'number': '201', 'type_id': 'type-standard', 'status': 'vacant'}, status: 'vacant');
    await put('room', 'room-203', {'number': '203', 'type_id': 'type-standard', 'status': 'vacant'}, status: 'vacant');
    await put('room', 'room-301', {'number': '301', 'type_id': 'type-suite', 'status': 'vacant'}, status: 'vacant');
  }

  Future<void> _addServer(Map<String, dynamic> action) async {
    final name = _required(action, 'name');
    final id = action['id']?.toString().trim().isNotEmpty == true ? action['id'].toString() : const Uuid().v4();
    await _save('server', id, {'name': name});
  }

  Future<void> _openOrder(Map<String, dynamic> action) async {
    final tableId = _required(action, 'table_id');
    final table = await _doc(tableId);
    if (table['status'] == 'occupied') throw Exception('Table déjà occupée');
    final id = const Uuid().v4();
    final checkId = const Uuid().v4();
    final order = {
      'table_id': tableId,
      'table_label': table['label'],
      'server_id': action['server_id'],
      'server_name': action['server_name']?.toString() ?? '',
      'status': 'open',
      'lines': <Map<String, dynamic>>[],
      'checks': [
        {'id': checkId, 'label': 'Addition 1', 'status': 'open'},
      ],
    };
    await _save('order', id, order, parentId: tableId, status: 'open');
    table['status'] = 'occupied';
    table['order_id'] = id;
    await _save('table', tableId, table, parentId: table['zone_id']?.toString(), status: 'occupied');
  }

  Future<void> _addLine(Map<String, dynamic> action) async {
    final order = await _doc(_required(action, 'order_id'));
    final checks = _maps(order['checks']);
    final openCheck = checks.cast<Map<String, dynamic>?>().firstWhere(
      (check) => check?['status'] == 'open',
      orElse: () => null,
    );
    if (openCheck == null) throw Exception('Aucune addition ouverte');
    final lines = _maps(order['lines']);
    lines.add({
      'id': const Uuid().v4(),
      'name': _required(action, 'name'),
      'quantity': (action['quantity'] as num?)?.toInt() ?? 1,
      'unit_price': (action['unit_price'] as num?)?.toInt() ?? 0,
      'course': action['course']?.toString() ?? 'plat',
      'product_id': action['product_id'],
      'check_id': openCheck['id'],
    });
    order['lines'] = lines;
    if (order['status'] == 'served' || order['status'] == 'ready') order['status'] = 'open';
    await _save('order', order['id'].toString(), order, parentId: order['table_id']?.toString(), status: order['status']?.toString());
  }

  Future<void> _sendCourse(Map<String, dynamic> action) async {
    final order = await _doc(_required(action, 'order_id'));
    final course = action['course']?.toString() ?? 'plat';
    final pending = _maps(order['lines']).where((line) => line['course'] == course && line['ticket_id'] == null).toList();
    if (pending.isEmpty) throw Exception('Rien à envoyer pour cette suite');
    final ticketId = const Uuid().v4();
    for (final line in pending) {
      line['ticket_id'] = ticketId;
    }
    await _save('ticket', ticketId, {
      'order_id': order['id'],
      'table_label': order['table_label'],
      'server_name': order['server_name'],
      'course': course,
      'status': 'sent',
      'sent_at': DateTime.now().toIso8601String(),
      'lines': pending.map((line) => {'name': line['name'], 'quantity': line['quantity']}).toList(),
    }, parentId: order['id']?.toString(), status: 'sent');
    order['status'] = 'kitchen';
    await _save('order', order['id'].toString(), order, parentId: order['table_id']?.toString(), status: 'kitchen');
  }

  Future<void> _setTicketStatus(Map<String, dynamic> action) async {
    final ticket = await _doc(_required(action, 'ticket_id'));
    final status = _required(action, 'status');
    const flow = ['sent', 'preparing', 'ready', 'served'];
    if (!flow.contains(status)) throw Exception('Statut cuisine invalide');
    ticket['status'] = status;
    await _save('ticket', ticket['id'].toString(), ticket, parentId: ticket['order_id']?.toString(), status: status);
    final order = await _doc(ticket['order_id'].toString());
    final tickets = await _children('ticket', order['id'].toString());
    if (tickets.every((item) => item['status'] == 'served')) {
      order['status'] = 'served';
    } else if (tickets.any((item) => item['status'] == 'ready')) {
      order['status'] = 'ready';
    } else if (tickets.any((item) => item['status'] == 'preparing')) {
      order['status'] = 'preparing';
    } else {
      order['status'] = 'kitchen';
    }
    await _save('order', order['id'].toString(), order, parentId: order['table_id']?.toString(), status: order['status']?.toString());
  }

  Future<void> _splitLines(Map<String, dynamic> action) async {
    final order = await _doc(_required(action, 'order_id'));
    final ids = (action['line_ids'] as List<dynamic>? ?? []).map((id) => id.toString()).toSet();
    if (ids.isEmpty) throw Exception('Choisissez des lignes à séparer');
    final checks = _maps(order['checks']);
    final checkId = const Uuid().v4();
    checks.add({'id': checkId, 'label': 'Addition ${checks.length + 1}', 'status': 'open'});
    var moved = 0;
    for (final line in _maps(order['lines'])) {
      if (!ids.contains(line['id'])) continue;
      line['check_id'] = checkId;
      moved++;
    }
    if (moved == 0) throw Exception('Lignes introuvables');
    order['checks'] = checks;
    await _save('order', order['id'].toString(), order, parentId: order['table_id']?.toString(), status: order['status']?.toString());
  }

  Future<void> _payCheck(Map<String, dynamic> action) async {
    final order = await _doc(_required(action, 'order_id'));
    final check = _check(order, _required(action, 'check_id'));
    if (check['status'] != 'open') throw Exception('Addition déjà fermée');
    final lines = _checkLines(order, check['id'].toString());
    if (lines.isEmpty) throw Exception('Addition vide');
    final sale = await _invoice(
      lines: lines,
      notes: 'Table ${order['table_label']} · ${check['label']}',
      method: 'cash',
    );
    check['status'] = 'paid';
    check['sale_id'] = sale.saleId;
    check['reference'] = sale.reference;
    await _closeOrderIfDone(order);
  }

  Future<void> _chargeRoom(Map<String, dynamic> action) async {
    final order = await _doc(_required(action, 'order_id'));
    final room = await _doc(_required(action, 'room_id'));
    if (room['status'] != 'occupied') throw Exception('Chambre ${room['number']} non occupée');
    final check = _check(order, _required(action, 'check_id'));
    if (check['status'] != 'open') throw Exception('Addition déjà fermée');
    final lines = _checkLines(order, check['id'].toString());
    if (lines.isEmpty) throw Exception('Addition vide');
    final folio = await _openFolioForRoom(room['id'].toString());
    final folioLines = _maps(folio['lines']);
    for (final line in lines) {
      folioLines.add({
        'id': const Uuid().v4(),
        'kind': 'restaurant',
        'description': 'Table ${order['table_label']} · ${line['name']}',
        'amount': ((line['unit_price'] as num?)?.toInt() ?? 0) * ((line['quantity'] as num?)?.toInt() ?? 0),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    folio['lines'] = folioLines;
    await _save('folio', folio['id'].toString(), folio, parentId: room['id'].toString(), status: 'open');
    check['status'] = 'folio';
    check['room_id'] = room['id'];
    check['room_number'] = room['number'];
    await _closeOrderIfDone(order);
  }

  Future<String> _createReservation(Map<String, dynamic> action) async {
    final room = await _doc(_required(action, 'room_id'));
    if (room['status'] != 'vacant') throw Exception('Chambre non libre');
    final guestName = _required(action, 'guest_name');
    final guestId = const Uuid().v4();
    final id = const Uuid().v4();
    final arrive = DateTime.now();
    final nights = _nights(action['nights']);
    await _save('guest', guestId, {
      'name': guestName,
      'room_id': room['id'],
      'room_number': room['number'],
    });
    await _save('reservation', id, {
      'room_id': room['id'],
      'room_number': room['number'],
      'type_id': room['type_id'],
      'guest_id': guestId,
      'guest_name': guestName,
      'nights': nights,
      'arrive_on': arrive.toIso8601String(),
      'depart_on': arrive.add(Duration(days: nights)).toIso8601String(),
      'status': 'reserved',
    }, parentId: room['id'].toString(), status: 'reserved');
    room['status'] = 'reserved';
    room['guest_name'] = guestName;
    room['guest_id'] = guestId;
    await _save('room', room['id'].toString(), room, status: 'reserved');
    return id;
  }

  Future<void> _arrive(Map<String, dynamic> action) async {
    final reservationId = await _createReservation(action);
    await _checkIn({'reservation_id': reservationId});
  }

  Future<void> _checkIn(Map<String, dynamic> action) async {
    final reservation = await _doc(_required(action, 'reservation_id'));
    if (reservation['status'] != 'reserved') throw Exception('Réservation non ouvrable');
    final room = await _doc(reservation['room_id'].toString());
    final folioId = const Uuid().v4();
    final nights = _nights(reservation['nights']);
    final folio = {
      'room_id': room['id'],
      'room_number': room['number'],
      'reservation_id': reservation['id'],
      'guest_id': reservation['guest_id'],
      'guest_name': reservation['guest_name'],
      'status': 'open',
      'lines': <Map<String, dynamic>>[],
    };
    await _addStayLine(folio, room, nights);
    await _save('folio', folioId, folio, parentId: room['id'].toString(), status: 'open');
    reservation['status'] = 'checked_in';
    reservation['folio_id'] = folioId;
    await _save('reservation', reservation['id'].toString(), reservation, parentId: room['id'].toString(), status: 'checked_in');
    room['status'] = 'occupied';
    room['guest_name'] = reservation['guest_name'];
    room['guest_id'] = reservation['guest_id'];
    room['folio_id'] = folioId;
    await _save('room', room['id'].toString(), room, status: 'occupied');
  }

  Future<void> _checkOut(Map<String, dynamic> action) async {
    final reservation = await _doc(_required(action, 'reservation_id'));
    if (reservation['status'] != 'checked_in') throw Exception('Aucun séjour en cours');
    final folio = await _doc(reservation['folio_id'].toString());
    final lines = _maps(folio['lines']);
    if (lines.isNotEmpty) {
      final sale = await _invoice(
        lines: lines
            .map((line) => {
                  'name': line['description'],
                  'quantity': 1,
                  'unit_price': line['amount'],
                })
            .toList(),
        notes: 'Facture hôtel · Chambre ${folio['room_number']} · ${folio['guest_name']}',
        method: 'cash',
      );
      folio['sale_id'] = sale.saleId;
      folio['reference'] = sale.reference;
    }
    folio['status'] = 'closed';
    await _save('folio', folio['id'].toString(), folio, parentId: folio['room_id']?.toString(), status: 'closed');
    reservation['status'] = 'checked_out';
    await _save('reservation', reservation['id'].toString(), reservation, parentId: reservation['room_id']?.toString(), status: 'checked_out');
    final room = await _doc(reservation['room_id'].toString());
    room['status'] = 'vacant';
    room.remove('guest_name');
    room.remove('guest_id');
    room.remove('folio_id');
    room['last_invoice'] = folio['reference'];
    await _save('room', room['id'].toString(), room, status: 'vacant');
  }

  Future<void> _postFolio(Map<String, dynamic> action) async {
    final room = await _doc(_required(action, 'room_id'));
    if (room['status'] != 'occupied') throw Exception('Chambre non occupée');
    final kind = action['kind']?.toString() ?? 'minibar';
    if (kind != 'minibar' && kind != 'room_service') throw Exception('Type de consommation invalide');
    final folio = await _openFolioForRoom(room['id'].toString());
    final lines = _maps(folio['lines']);
    lines.add({
      'id': const Uuid().v4(),
      'kind': kind,
      'description': action['description']?.toString().trim().isNotEmpty == true
          ? action['description'].toString()
          : (kind == 'minibar' ? 'Minibar' : 'Room service'),
      'amount': (action['amount'] as num?)?.toInt() ?? 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    folio['lines'] = lines;
    await _save('folio', folio['id'].toString(), folio, parentId: room['id'].toString(), status: 'open');
  }

  Future<void> _closeOrderIfDone(Map<String, dynamic> order) async {
    final checks = _maps(order['checks']);
    final done = checks.every((check) => check['status'] != 'open');
    if (done) order['status'] = 'paid';
    await _save('order', order['id'].toString(), order, parentId: order['table_id']?.toString(), status: order['status']?.toString());
    if (!done) return;
    final table = await _doc(order['table_id'].toString());
    table['status'] = 'free';
    table.remove('order_id');
    await _save('table', table['id'].toString(), table, parentId: table['zone_id']?.toString(), status: 'free');
  }

  int _nights(dynamic value) {
    final nights = (value as num?)?.toInt() ?? int.tryParse(value?.toString() ?? '') ?? 1;
    return nights < 1 ? 1 : nights;
  }

  Future<void> _addStayLine(Map<String, dynamic> folio, Map<String, dynamic> room, int nights) async {
    final typeId = room['type_id']?.toString() ?? '';
    if (typeId.isEmpty) return;
    Map<String, dynamic> type;
    try {
      type = await _doc(typeId);
    } catch (_) {
      return;
    }
    final rate = (type['rate'] as num?)?.toInt() ?? 0;
    if (rate <= 0) return;
    final lines = _maps(folio['lines']);
    lines.add({
      'id': const Uuid().v4(),
      'kind': 'stay',
      'description': '${type['name'] ?? 'Chambre'} · $nights nuit${nights > 1 ? 's' : ''}',
      'amount': rate * nights,
      'created_at': DateTime.now().toIso8601String(),
    });
    folio['lines'] = lines;
  }

  Future<Map<String, dynamic>> _openFolioForRoom(String roomId) async {
    final room = await _doc(roomId);
    final folioId = room['folio_id']?.toString();
    if (folioId != null && folioId.isNotEmpty) return _doc(folioId);
    throw Exception('Aucun folio ouvert pour cette chambre');
  }

  Future<PosSaleResult> _invoice({
    required List<Map<String, dynamic>> lines,
    required String notes,
    required String method,
  }) {
    final items = lines
        .map((line) => {
              'name': line['name'],
              if (line['product_id'] != null) 'product_id': line['product_id'],
              'quantity': (line['quantity'] as num?)?.toInt() ?? 1,
              'unit_price': (line['unit_price'] as num?)?.toInt() ?? 0,
            })
        .toList();
    final total = items.fold<int>(0, (sum, item) => sum + ((item['unit_price'] as int) * (item['quantity'] as int)));
    return OfflineStore.instance.commitSale(
      items: items,
      payments: [
        {'method': method, 'amount': total},
      ],
      notes: notes,
      total: total,
      paidAmount: total,
      outstandingAmount: 0,
      method: method,
    );
  }

  Map<String, dynamic> _check(Map<String, dynamic> order, String checkId) {
    return _maps(order['checks']).firstWhere((check) => check['id'] == checkId);
  }

  List<Map<String, dynamic>> _checkLines(Map<String, dynamic> order, String checkId) {
    return _maps(order['lines']).where((line) => line['check_id'] == checkId).toList();
  }

  Future<List<Map<String, dynamic>>> _children(String kind, String parentId) async {
    final db = await _db;
    final rows = await db.query('hospitality_docs', where: 'kind = ? AND parent_id = ?', whereArgs: [kind, parentId]);
    return rows.map((row) => jsonDecode(row['json'] as String) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> _doc(String id) async {
    final db = await _db;
    final rows = await db.query('hospitality_docs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw Exception('Document introuvable');
    final json = jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
    json['id'] = rows.first['id'];
    return json;
  }

  Future<void> _save(String kind, String id, Map<String, dynamic> json, {String? parentId, String? status}) async {
    final db = await _db;
    json['id'] = id;
    await db.insert(
      'hospitality_docs',
      {
        'id': id,
        'kind': kind,
        'parent_id': parentId,
        'status': status,
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _required(Map<String, dynamic> action, String key) {
    final value = action[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw Exception('$key requis');
    return value;
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
}
