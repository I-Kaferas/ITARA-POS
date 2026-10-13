import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/document_dao.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/sync_numbers.dart';
import '../domain/shift_models.dart';

/// Caisses, shifts et mouvements lus et écrits uniquement en local.
class LocalShiftsStore {
  LocalShiftsStore._();

  static final LocalShiftsStore instance = LocalShiftsStore._();

  static const movementTypes = [
    MovementType(value: 'cash_in', label: 'Cash in', labelFr: 'Entrée', direction: 'in'),
    MovementType(value: 'cash_out', label: 'Cash out', labelFr: 'Sortie', direction: 'out'),
    MovementType(value: 'expense', label: 'Expense', labelFr: 'Dépense', direction: 'out'),
  ];

  /// The open shift for this till, preferring the register already selected.
  Future<({CashRegister register, CashRegisterSession session})?> openShift() async {
    final registers = await fetchRegisters();
    final config = TerminalConfigRepository.instance.config;
    ({CashRegister register, CashRegisterSession session})? fallback;
    for (final register in registers) {
      final session = register.openSession;
      if (session == null || !session.isOpen) continue;
      final match = (
        register: register,
        session: session,
      );
      if (register.id == config.cashRegisterId || session.id == config.cashSessionId) {
        return match;
      }
      fallback ??= match;
    }
    return fallback;
  }

  Future<List<CashRegister>> fetchRegisters() async {
    final storeId = TerminalConfigRepository.instance.config.storeId.trim();
    final rows = await DataModelDaos.cashRegisters.list(
      where: storeId.isEmpty ? null : "store_id = ? OR store_id IS NULL OR store_id = ''",
      whereArgs: storeId.isEmpty ? null : [storeId],
      orderBy: 'name ASC',
    );
    final registers = <CashRegister>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (_inactive(row)) continue;
      registers.add(CashRegister(
        id: id,
        name: row['name']?.toString() ?? 'Caisse',
        code: row['code']?.toString() ?? '',
        isActive: true,
        openSession: await _openSession(id),
      ));
    }
    return registers;
  }

  Future<CashRegister> createRegister({
    required String name,
    required String code,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final storeId = TerminalConfigRepository.instance.config.storeId.trim();
    final document = {
      'id': id,
      'name': name,
      'code': code,
      'is_active': true,
      'store_id': storeId,
      'updated_at': now,
    };
    await DataModelDaos.cashRegisters.upsert(document, columns: {
      'store_id': storeId,
      'code': code,
      'name': name,
      'is_active': 1,
      'updated_at': now,
    });
    return CashRegister(id: id, name: name, code: code, isActive: true);
  }

  Future<CurrentSessionResponse> currentSession(String registerId) async {
    final session = await _openSession(registerId);
    if (session == null) return const CurrentSessionResponse();
    final summary = await _summary(session);
    return CurrentSessionResponse(session: session, summary: summary, zReport: summary);
  }

  Future<SessionSummary> summaryFor(CashRegisterSession session) => _summary(session);

  Future<CashRegisterSession?> openShiftForCashier(String cashierId) async {
    await _releaseFinishedShifts();
    final visibleIds = (await fetchRegisters()).map((register) => register.id).toSet();
    final rows = await DataModelDaos.shifts.list(
      where: "lower(status) = ? AND (closed_at IS NULL OR closed_at = '')",
      whereArgs: ['open'],
      orderBy: 'opened_at DESC',
    );
    final mine = cashierId.trim();
    for (final row in rows) {
      final registerId = row['cash_register_id']?.toString() ?? '';
      if (!visibleIds.contains(registerId)) continue;
      final session = CashRegisterSession.fromJson(_sessionJson(row));
      if (!session.isOpen) continue;
      final owner = session.openedById?.trim() ?? '';
      if (mine.isNotEmpty && owner.isNotEmpty && owner != mine) continue;
      return session;
    }
    return null;
  }

  Future<CurrentSessionResponse> openSession({
    required String registerId,
    required int openingBalance,
    String? notes,
  }) async {
    final config = TerminalConfigRepository.instance.config;
    final mine = await openShiftForCashier(config.cashierId);
    if (mine != null) {
      throw Exception('Close your current shift before opening another.');
    }
    final existing = await _openSession(registerId);
    if (existing != null) {
      throw Exception('This register already has an open shift.');
    }

    final id = const Uuid().v4();
    final now = DateTime.now();
    final openedBy = config.cashierName.trim().isEmpty ? 'Caissier' : config.cashierName.trim();
    final document = {
      'id': id,
      'cash_register_id': registerId,
      'cash_session_id': id,
      'user_id': config.cashierId,
      'status': 'open',
      'opened_at': now.toIso8601String(),
      'opening_balance': openingBalance,
      'opening_notes': notes ?? '',
      'opened_by_user': {'name': openedBy},
    };
    await DataModelDaos.shifts.upsert(document, columns: {
      'cash_register_id': registerId,
      'cash_session_id': id,
      'user_id': config.cashierId,
      'status': 'open',
      'opened_at': now.toIso8601String(),
    });
    await TerminalConfigRepository.instance.save(
      config.copyWith(cashRegisterId: registerId, cashSessionId: id),
    );
    final session = CashRegisterSession.fromJson(document);
    final summary = await _summary(session);
    return CurrentSessionResponse(session: session, summary: summary, zReport: summary);
  }

  Future<CurrentSessionResponse> closeSession({
    required String registerId,
    required int actualCash,
    String? notes,
  }) async {
    final session = await _openSession(registerId);
    if (session == null) {
      throw Exception('Aucun shift ouvert');
    }
    final summary = await _summary(session);
    final variance = actualCash - summary.expectedCash;
    final closedAt = DateTime.now();
    final openRows = await DataModelDaos.shifts.list(
      where: 'cash_register_id = ? AND lower(status) = ?',
      whereArgs: [registerId, 'open'],
    );
    for (final row in openRows) {
      await _markClosed(
        row,
        closedAt: closedAt,
        actualCash: row['id']?.toString() == session.id ? actualCash : null,
        notes: row['id']?.toString() == session.id ? notes : null,
        expectedCash: row['id']?.toString() == session.id ? summary.expectedCash : null,
        variance: row['id']?.toString() == session.id ? variance : null,
      );
    }
    final repo = TerminalConfigRepository.instance;
    if (repo.config.cashSessionId == session.id) {
      await repo.save(repo.config.copyWith(cashSessionId: ''));
    }
    final closed = CashRegisterSession(
      id: session.id,
      status: 'closed',
      openingBalance: session.openingBalance,
      openedAt: session.openedAt,
      actualCash: actualCash,
      variance: variance,
      openingNotes: session.openingNotes,
      closingNotes: notes,
      closedAt: closedAt,
      openedByName: session.openedByName,
      openedById: session.openedById,
    );
    final report = SessionSummary(
      openingBalance: summary.openingBalance,
      salesTotal: summary.salesTotal,
      cashInTotal: summary.cashInTotal,
      cashOutTotal: summary.cashOutTotal,
      expensesTotal: summary.expensesTotal,
      expectedCash: summary.expectedCash,
      actualCash: actualCash,
      variance: variance,
      invoicesCount: summary.invoicesCount,
      invoicesTotal: summary.invoicesTotal,
      invoices: summary.invoices,
      paymentMethods: summary.paymentMethods,
      openedAt: summary.openedAt,
      closedAt: closedAt,
      handover: summary.handover,
    );
    return CurrentSessionResponse(session: closed, summary: report, zReport: report);
  }

  Future<List<CashRegisterSession>> fetchSessions(String registerId) async {
    final rows = await DataModelDaos.shifts.list(
      where: 'cash_register_id = ?',
      whereArgs: [registerId],
      orderBy: 'opened_at DESC',
    );
    return rows.map((row) => CashRegisterSession.fromJson(_sessionJson(row))).toList();
  }

  Future<List<MovementType>> fetchMovementTypes() async => movementTypes;

  Future<SessionSummary> recordMovement({
    required String registerId,
    required String movementType,
    required int amount,
    String? description,
  }) async {
    final session = await _openSession(registerId);
    if (session == null) throw Exception('Aucun shift ouvert');
    final now = DateTime.now().toIso8601String();
    final id = const Uuid().v4();
    await DataModelDaos.cashMovements.upsert({
      'id': id,
      'cash_register_id': registerId,
      'cash_session_id': session.id,
      'type': movementType,
      'amount': amount,
      'memo': description ?? '',
      'created_at': now,
    }, columns: {
      'cash_register_id': registerId,
      'cash_session_id': session.id,
      'type': movementType,
      'amount': amount,
      'memo': description ?? '',
      'user_id': TerminalConfigRepository.instance.config.cashierId,
      'created_at': now,
    });
    return _summary(session);
  }

  /// A shift already closed (or left open on a register that no longer exists)
  /// must not block the next opening.
  Future<void> _releaseFinishedShifts() async {
    final knownIds = (await DataModelDaos.cashRegisters.list()).map((row) => row['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
    final rows = await DataModelDaos.shifts.list(
      where: "lower(status) = ?",
      whereArgs: ['open'],
    );
    for (final row in rows) {
      final closedAt = row['closed_at']?.toString().trim() ?? '';
      final registerId = row['cash_register_id']?.toString() ?? '';
      final finished = closedAt.isNotEmpty || (registerId.isNotEmpty && !knownIds.contains(registerId));
      if (!finished) continue;
      await _markClosed(row);
    }
  }

  Future<void> _markClosed(
    Map<String, dynamic> row, {
    DateTime? closedAt,
    int? actualCash,
    String? notes,
    int? expectedCash,
    int? variance,
  }) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final when = closedAt ?? DateTime.tryParse(row['closed_at']?.toString() ?? '') ?? DateTime.now();
    final openedAt = row['opened_at']?.toString().trim();
    final extras = <String, Object?>{};
    if (actualCash != null) extras['actual_cash'] = actualCash;
    if (expectedCash != null) extras['expected_cash'] = expectedCash;
    if (variance != null) extras['variance'] = variance;
    if (notes != null) extras['closing_notes'] = notes;
    final document = {
      ...row,
      'id': id,
      'status': 'closed',
      'closed_at': when.toIso8601String(),
      'cash_session_id': row['cash_session_id']?.toString().isNotEmpty == true ? row['cash_session_id'] : id,
      ...extras,
    };
    document.remove('json');
    await DataModelDaos.shifts.upsert(document, columns: {
      'cash_register_id': row['cash_register_id']?.toString() ?? '',
      'cash_session_id': document['cash_session_id']?.toString() ?? id,
      'user_id': row['user_id']?.toString() ?? '',
      'status': 'closed',
      'opened_at': (openedAt == null || openedAt.isEmpty) ? when.toIso8601String() : openedAt,
      'closed_at': when.toIso8601String(),
    });
  }

  Future<CashRegisterSession?> _openSession(String registerId) async {
    final rows = await DataModelDaos.shifts.list(
      where: "cash_register_id = ? AND lower(status) = ? AND (closed_at IS NULL OR closed_at = '')",
      whereArgs: [registerId, 'open'],
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CashRegisterSession.fromJson(_sessionJson(rows.first));
  }

  Map<String, dynamic> _sessionJson(Map<String, dynamic> row) {
    final openedBy = row['opened_by_user'];
    return {
      ...row,
      'id': row['id']?.toString() ?? row['cash_session_id']?.toString() ?? '',
      'status': row['status']?.toString() ?? 'open',
      'opened_at': row['opened_at']?.toString() ?? DateTime.now().toIso8601String(),
      'opened_by_user': openedBy is Map ? Map<String, dynamic>.from(openedBy) : openedBy,
    };
  }

  Future<SessionSummary> _summary(CashRegisterSession session) async {
    final db = await LocalDatabase.instance.database;
    final sales = await db.query(
      'sales',
      where: 'cash_session_id = ?',
      whereArgs: [session.id],
      orderBy: 'created_at DESC',
    );
    final saleIds = sales.map((row) => row['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
    final payments = saleIds.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'payments',
            where: 'sale_id IN (${List.filled(saleIds.length, '?').join(',')})',
            whereArgs: saleIds,
          );
    final movements = await db.query(
      'cash_movements',
      where: 'cash_session_id = ?',
      whereArgs: [session.id],
    );

    var cashSales = 0;
    final byMethod = <String, ({int count, int amount})>{};
    for (final payment in payments) {
      final method = payment['method']?.toString().trim().isNotEmpty == true
          ? payment['method'].toString()
          : 'cash';
      final amount = syncAsInt(payment['amount']);
      final current = byMethod[method];
      byMethod[method] = (count: (current?.count ?? 0) + 1, amount: (current?.amount ?? 0) + amount);
      if (method == 'cash') cashSales += amount;
    }
    if (byMethod.isEmpty) {
      for (final sale in sales) {
        final method = sale['method']?.toString().trim().isNotEmpty == true
            ? sale['method'].toString()
            : 'cash';
        final amount = syncAsInt(sale['total']);
        final current = byMethod[method];
        byMethod[method] = (count: (current?.count ?? 0) + 1, amount: (current?.amount ?? 0) + amount);
        if (method == 'cash') cashSales += amount;
      }
    }

    var cashIn = 0;
    var cashOut = 0;
    var expenses = 0;
    for (final movement in movements) {
      final amount = syncAsInt(movement['amount']);
      switch (movement['type']?.toString()) {
        case 'cash_in':
          cashIn += amount;
        case 'cash_out':
          cashOut += amount;
        case 'expense':
          expenses += amount;
      }
    }

    final customerNames = await _customerNames(db, sales);
    final salesTotal = sales.fold<int>(0, (sum, row) => sum + syncAsInt(row['total']));
    final expected = session.openingBalance + cashSales + cashIn - cashOut - expenses;
    final handover = await _handover(sales);
    return SessionSummary(
      openingBalance: session.openingBalance,
      salesTotal: salesTotal,
      cashInTotal: cashIn,
      cashOutTotal: cashOut,
      expensesTotal: expenses,
      expectedCash: expected,
      invoicesCount: sales.length,
      invoicesTotal: salesTotal,
      invoices: sales.map((row) => _invoiceFromSale(row, customerNames)).toList(),
      paymentMethods: byMethod.entries
          .map((entry) => PaymentMethodBreakdown(
                method: entry.key,
                label: entry.key.replaceAll('_', ' '),
                count: entry.value.count,
                amount: entry.value.amount,
              ))
          .toList(),
      openedAt: session.openedAt,
      closedAt: session.closedAt,
      handover: handover,
    );
  }

  Future<ShiftHandover> _handover(List<Map<String, Object?>> sales) async {
    if (sales.isEmpty) {
      return ShiftHandover(currency: AppConfig.currencyCode);
    }

    final db = await LocalDatabase.instance.database;
    final saleIds = sales.map((row) => row['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
    final itemRows = saleIds.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'sale_items',
            where: 'sale_id IN (${List.filled(saleIds.length, '?').join(',')})',
            whereArgs: saleIds,
          );
    final itemsBySale = <String, List<Map<String, dynamic>>>{};
    for (final row in itemRows) {
      final saleId = row['sale_id']?.toString() ?? '';
      if (saleId.isEmpty) continue;
      itemsBySale.putIfAbsent(saleId, () => []).add(_itemMap(row));
    }

    final productIds = <String>{};
    for (final sale in sales) {
      final saleId = sale['id']?.toString() ?? '';
      final items = itemsBySale[saleId] ?? _payloadItems(sale);
      itemsBySale[saleId] = items;
      for (final item in items) {
        final id = item['product_id']?.toString() ?? '';
        if (id.isNotEmpty) productIds.add(id);
      }
    }

    final products = <String, Map<String, Object?>>{};
    if (productIds.isNotEmpty) {
      final rows = await db.query(
        'products',
        where: 'product_id IN (${List.filled(productIds.length, '?').join(',')})',
        whereArgs: productIds.toList(),
      );
      for (final row in rows) {
        final id = row['product_id']?.toString() ?? '';
        if (id.isNotEmpty) products[id] = row;
      }
    }

    final stockRows = productIds.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'stocks',
            where: 'product_id IN (${List.filled(productIds.length, '?').join(',')})',
            whereArgs: productIds.toList(),
          );

    final storeNames = await _storeNames();
    final groups = <String, _StoreAgg>{};
    var articlesSold = 0;
    var articlesOnCredit = 0;
    var creditSalesTotal = 0;
    var creditOrders = 0;
    String? currency;

    for (final sale in sales) {
      currency ??= _saleCurrency(sale);
      final total = syncAsInt(sale['total']);
      final onCredit = _saleOnCredit(sale);
      if (onCredit) {
        creditOrders++;
        creditSalesTotal += total;
      }
      final storeId = sale['store_id']?.toString() ?? '';
      final group = groups.putIfAbsent(storeId, () => _StoreAgg(storeId, storeNames[storeId] ?? 'Magasin'));
      final saleId = sale['id']?.toString() ?? '';
      for (final item in itemsBySale[saleId] ?? const <Map<String, dynamic>>[]) {
        final sold = syncAsInt(item['quantity']);
        if (sold <= 0) continue;
        final productId = item['product_id']?.toString() ?? '';
        final product = products[productId];
        final name = _firstText([
          item['product_name'],
          item['name'],
          product?['name'],
        ], 'Article');
        final code = _firstText([
          item['product_sku'],
          item['sku'],
          product?['sku'],
        ], '');
        final lineTotal = syncAsInt(item['line_total']) > 0
            ? syncAsInt(item['line_total'])
            : syncAsInt(item['unit_price']) * sold;
        final key = productId.isNotEmpty ? productId : '$name|$code';
        final line = group.lines.putIfAbsent(
          key,
          () => _LineAgg(
            name: name,
            code: code,
            remaining: _onHand(
              productId: productId,
              storeId: storeId,
              products: products,
              stockRows: stockRows,
            ),
          ),
        );
        line.sold += sold;
        if (onCredit) line.creditQty += sold;
        line.total += lineTotal;
        articlesSold += sold;
        if (onCredit) articlesOnCredit += sold;
      }
    }

    final stores = groups.values.where((group) => group.lines.isNotEmpty).map((group) {
      final lines = group.lines.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return ShiftStoreGroup(
        id: group.id,
        name: group.name,
        lines: [
          for (final line in lines)
            ShiftSoldLine(
              name: line.name,
              code: line.code,
              sold: line.sold,
              creditQty: line.creditQty,
              remaining: line.remaining,
              total: line.total,
            ),
        ],
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return ShiftHandover(
      articlesSold: articlesSold,
      articlesOnCredit: articlesOnCredit,
      ordersCount: sales.length,
      storesCount: stores.length,
      creditSalesTotal: creditSalesTotal,
      creditOrdersCount: creditOrders,
      currency: currency ?? AppConfig.currencyCode,
      stores: stores,
    );
  }

  Map<String, dynamic> _itemMap(Map<String, Object?> row) {
    Map<String, dynamic> json = {};
    try {
      final decoded = jsonDecode(row['json']?.toString() ?? '{}');
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {
      ...json,
      'product_id': row['product_id'] ?? json['product_id'],
      'quantity': row['quantity'] ?? json['quantity'],
      'unit_price': row['unit_price'] ?? json['unit_price'],
      'line_total': row['line_total'] ?? json['line_total'],
    };
  }

  List<Map<String, dynamic>> _payloadItems(Map<String, Object?> sale) {
    try {
      final decoded = jsonDecode(sale['payload_json']?.toString() ?? '{}');
      if (decoded is! Map) return const [];
      final items = decoded['items'];
      if (items is! List) return const [];
      return items.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return const [];
    }
  }

  bool _saleOnCredit(Map<String, Object?> sale) {
    final total = syncAsInt(sale['total']);
    if (total <= 0) return false;
    final method = sale['method']?.toString() ?? '';
    return syncAsInt(sale['outstanding_amount']) > 0 ||
        syncAsInt(sale['paid_amount']) < total ||
        method == 'credit' ||
        method == 'on_credit';
  }

  String? _saleCurrency(Map<String, Object?> sale) {
    try {
      final decoded = jsonDecode(sale['payload_json']?.toString() ?? '{}');
      if (decoded is Map) {
        final code = decoded['currency']?.toString().trim() ?? '';
        if (code.isNotEmpty) return code;
      }
    } catch (_) {}
    return null;
  }

  /// Same on-hand figure as the product card: the catalog quantity, not a sum of stock rows.
  int? _onHand({
    required String productId,
    required String storeId,
    required Map<String, Map<String, Object?>> products,
    required List<Map<String, Object?>> stockRows,
  }) {
    if (productId.isEmpty) return null;
    final catalog = _catalogOnHand(products[productId]);
    if (catalog != null) return catalog;

    Map<String, Object?>? latest;
    for (final row in stockRows) {
      if (row['product_id']?.toString() != productId) continue;
      final rowStore = row['store_id']?.toString() ?? '';
      if (storeId.isNotEmpty && rowStore.isNotEmpty && rowStore != storeId) continue;
      final updated = row['updated_at']?.toString() ?? '';
      final previous = latest?['updated_at']?.toString() ?? '';
      if (latest == null || updated.compareTo(previous) > 0) latest = row;
    }
    if (latest == null) return null;
    try {
      final decoded = jsonDecode(latest['json']?.toString() ?? '{}');
      if (decoded is Map && decoded['quantity'] != null) return syncAsInt(decoded['quantity']);
    } catch (_) {}
    return latest['quantity'] == null ? null : syncAsInt(latest['quantity']);
  }

  int? _catalogOnHand(Map<String, Object?>? row) {
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row['json']?.toString() ?? '{}');
      if (decoded is Map && decoded['quantity_on_hand'] != null) {
        return syncAsInt(decoded['quantity_on_hand']);
      }
    } catch (_) {}
    return null;
  }

  String _firstText(List<Object?> values, String fallback) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  Future<Map<String, String>> _storeNames() async {
    final names = <String, String>{};
    final config = TerminalConfigRepository.instance.config;
    final brand = config.brandName.trim();
    if (config.storeId.trim().isNotEmpty && brand.isNotEmpty) {
      names[config.storeId.trim()] = brand;
    }
    final db = await LocalDatabase.instance.database;
    for (final table in ['branches', 'organizations']) {
      try {
        final rows = await db.query(table, columns: ['id', 'name']);
        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          final name = row['name']?.toString().trim() ?? '';
          if (id.isNotEmpty && name.isNotEmpty) names.putIfAbsent(id, () => name);
        }
      } catch (_) {}
    }
    return names;
  }

  Future<Map<String, String>> _customerNames(Database db, List<Map<String, Object?>> sales) async {
    final ids = <String>{};
    for (final row in sales) {
      final payload = _payload(row);
      final id = payload['customer_client_id']?.toString().trim() ?? payload['customer_id']?.toString().trim() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return const {};
    try {
      final rows = await db.query(
        'customers',
        columns: ['id', 'server_id', 'name'],
        where: 'id IN (${List.filled(ids.length, '?').join(',')}) OR server_id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: [...ids, ...ids],
      );
      final names = <String, String>{};
      for (final row in rows) {
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final id = row['id']?.toString() ?? '';
        final serverId = row['server_id']?.toString() ?? '';
        if (id.isNotEmpty) names[id] = name;
        if (serverId.isNotEmpty) names[serverId] = name;
      }
      return names;
    } catch (_) {
      return const {};
    }
  }

  Map<String, dynamic> _payload(Map<String, Object?> row) {
    final raw = row['payload_json']?.toString() ?? '';
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  ShiftInvoice _invoiceFromSale(Map<String, Object?> row, Map<String, String> customerNames) {
    final payload = _payload(row);
    final customerId = payload['customer_client_id']?.toString() ?? payload['customer_id']?.toString() ?? '';
    return ShiftInvoice(
      reference: row['reference']?.toString() ?? '',
      total: syncAsInt(row['total']),
      completedAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      itemCount: _itemCount(payload['items']),
      customerName: customerNames[customerId],
      method: row['method']?.toString(),
      outstanding: syncAsInt(row['outstanding_amount']),
      discount: _discountAmount(payload['discount']),
    );
  }

  int _itemCount(dynamic items) {
    if (items is! List) return 0;
    var count = 0;
    for (final raw in items) {
      if (raw is Map) {
        final quantity = raw['quantity'];
        final parsed = quantity is num ? quantity.round() : int.tryParse('$quantity') ?? 1;
        count += parsed < 1 ? 1 : parsed;
      } else {
        count += 1;
      }
    }
    return count;
  }

  int _discountAmount(dynamic discount) {
    if (discount is! Map) return 0;
    if (discount['type']?.toString() != 'fixed') return 0;
    return syncAsInt(discount['value']);
  }

  bool _inactive(Map<String, dynamic> row) {
    final value = row['is_active'];
    return value == 0 || value == false || value == '0';
  }
}

class _StoreAgg {
  _StoreAgg(this.id, this.name);

  final String id;
  final String name;
  final lines = <String, _LineAgg>{};
}

class _LineAgg {
  _LineAgg({
    required this.name,
    required this.code,
    required this.remaining,
  });

  final String name;
  final String code;
  final int? remaining;
  int sold = 0;
  int creditQty = 0;
  int total = 0;
}
