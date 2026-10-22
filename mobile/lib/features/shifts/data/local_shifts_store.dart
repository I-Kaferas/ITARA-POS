import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../data/local/document_dao.dart';
import '../../../data/local/local_database.dart';
import '../../../sync/sync_numbers.dart';
import '../domain/shift_models.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Caisses, shifts et mouvements lus et écrits uniquement en local.
class LocalShiftsStore {
  LocalShiftsStore._();

  static final LocalShiftsStore instance = LocalShiftsStore._();

  static final movementTypes = [
    MovementType(value: 'cash_in', label: tr('Cash in'), labelFr: 'Entrée', direction: 'in'),
    MovementType(value: 'cash_out', label: tr('Cash out'), labelFr: 'Sortie', direction: 'out'),
    MovementType(value: 'expense', label: tr('Expense'), labelFr: 'Dépense', direction: 'out'),
  ];

  /// Open shift for the connected cashier on the **active store**.
  Future<({CashRegister register, CashRegisterSession session})?> openShift({
    String? storeId,
  }) async {
    final config = TerminalConfigRepository.instance.config;
    final cashierId = config.cashierId.trim();
    if (cashierId.isEmpty) return null;

    final store = (storeId ?? config.storeId).trim();
    final mine = await openShiftForCashier(cashierId, storeId: store);
    if (mine == null) return null;

    final registerId = mine.cashRegisterId?.trim() ?? '';
    if (registerId.isNotEmpty) {
      final register = await _registerById(registerId);
      if (register != null) {
        return (register: register.copyWithSession(mine), session: mine);
      }
      return (
        register: CashRegister(
          id: registerId,
          name: 'Caisse',
          code: '',
          isActive: true,
          openSession: mine,
        ),
        session: mine,
      );
    }

    final registers = await fetchRegisters(storeId: store);
    for (final register in registers) {
      final session = register.openSession;
      if (session == null || session.id != mine.id) continue;
      return (register: register, session: session);
    }
    return null;
  }

  /// After a store switch: bind TerminalConfig to this cashier's shift for that store,
  /// or clear session pointers so POS requires opening a new shift.
  Future<({CashRegister register, CashRegisterSession session})?> syncTerminalShiftForStore(
    String storeId,
  ) async {
    final config = TerminalConfigRepository.instance.config;
    final cashierId = config.cashierId.trim();
    final store = storeId.trim();
    if (cashierId.isEmpty || store.isEmpty) {
      if (config.cashSessionId.isNotEmpty || config.cashRegisterId.isNotEmpty) {
        await TerminalConfigRepository.instance.save(
          config.copyWith(cashRegisterId: '', cashSessionId: ''),
        );
      }
      return null;
    }

    final open = await openShift(storeId: store);
    if (open == null) {
      await TerminalConfigRepository.instance.save(
        config.copyWith(cashRegisterId: '', cashSessionId: ''),
      );
      return null;
    }

    if (config.cashRegisterId != open.register.id ||
        config.cashSessionId != open.session.id) {
      await TerminalConfigRepository.instance.save(
        config.copyWith(
          cashRegisterId: open.register.id,
          cashSessionId: open.session.id,
        ),
      );
    }
    return open;
  }

  Future<CashRegister?> _registerById(String registerId) async {
    final row = await DataModelDaos.cashRegisters.find(registerId);
    if (row == null || _inactive(row)) return null;
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return CashRegister(
      id: id,
      name: row['name']?.toString() ?? 'Caisse',
      code: row['code']?.toString() ?? '',
      isActive: true,
      openSession: await _openSession(id),
    );
  }

  Future<List<CashRegister>> fetchRegisters({String? storeId}) async {
    final store = (storeId ?? TerminalConfigRepository.instance.config.storeId).trim();
    final rows = await DataModelDaos.cashRegisters.list(
      where: store.isEmpty ? null : "store_id = ? OR store_id IS NULL OR store_id = ''",
      whereArgs: store.isEmpty ? null : [store],
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

  Future<SessionPerformance> sessionPerformance(
    CashRegisterSession session, {
    required String sessionCode,
    required String registerName,
  }) async {
    final db = await LocalDatabase.instance.database;
    final sales = await db.query(
      'sales',
      where: 'cash_session_id = ?',
      whereArgs: [session.id],
      orderBy: 'created_at ASC',
    );
    final saleIds = sales.map((row) => row['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
    final itemRows = saleIds.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'sale_items',
            where: 'sale_id IN (${List.filled(saleIds.length, '?').join(',')})',
            whereArgs: saleIds,
          );
    final payments = saleIds.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'payments',
            where: 'sale_id IN (${List.filled(saleIds.length, '?').join(',')})',
            whereArgs: saleIds,
          );

    final itemsBySale = <String, List<Map<String, dynamic>>>{};
    final productIds = <String>{};
    for (final row in itemRows) {
      final saleId = row['sale_id']?.toString() ?? '';
      if (saleId.isEmpty) continue;
      final item = _itemMap(row);
      itemsBySale.putIfAbsent(saleId, () => []).add(item);
      final productId = item['product_id']?.toString() ?? '';
      if (productId.isNotEmpty) productIds.add(productId);
    }
    for (final sale in sales) {
      final saleId = sale['id']?.toString() ?? '';
      if (saleId.isEmpty || itemsBySale.containsKey(saleId)) continue;
      final payloadItems = _payloadItems(sale);
      if (payloadItems.isEmpty) continue;
      itemsBySale[saleId] = payloadItems;
      for (final item in payloadItems) {
        final productId = item['product_id']?.toString() ?? '';
        if (productId.isNotEmpty) productIds.add(productId);
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
    final categoryIds = products.values
        .map((row) => row['category_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final categoryNames = <String, String>{};
    if (categoryIds.isNotEmpty) {
      final rows = await db.query(
        'categories',
        where: 'id IN (${List.filled(categoryIds.length, '?').join(',')})',
        whereArgs: categoryIds.toList(),
      );
      for (final row in rows) {
        final id = row['id']?.toString() ?? '';
        final name = row['name']?.toString().trim() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) categoryNames[id] = name;
      }
    }

    final storeNames = await _storeNames();
    final fallbackDepartment = registerName.trim().isEmpty ? 'Magasin' : registerName.trim();
    final departments = <String, _DepartmentAgg>{};
    final productQty = <String, int>{};
    final storeIds = <String>{};
    var gross = 0;
    var collected = 0;
    var outstanding = 0;
    var paidInvoices = 0;
    var creditInvoices = 0;

    for (final sale in sales) {
      final saleId = sale['id']?.toString() ?? '';
      final total = syncAsInt(sale['total']);
      final paid = syncAsInt(sale['paid_amount']);
      final due = syncAsInt(sale['outstanding_amount']);
      final onCredit = _saleOnCredit(sale);
      gross += total;
      collected += onCredit ? paid : (paid > 0 ? paid : total);
      outstanding += onCredit ? (due > 0 ? due : total - paid) : 0;
      if (onCredit) {
        creditInvoices++;
      } else if (total > 0 || paid > 0) {
        paidInvoices++;
      }
      final storeId = sale['store_id']?.toString() ?? '';
      if (storeId.isNotEmpty) storeIds.add(storeId);

      final buckets = <String, int>{};
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
        productQty[name] = (productQty[name] ?? 0) + sold;
        final categoryId = product?['category_id']?.toString() ?? item['category_id']?.toString() ?? '';
        final department = _firstText([
          categoryNames[categoryId],
          item['category_name'],
          storeNames[storeId],
          fallbackDepartment,
        ], fallbackDepartment);
        final lineTotal = syncAsInt(item['line_total']) > 0
            ? syncAsInt(item['line_total'])
            : syncAsInt(item['unit_price']) * sold;
        buckets[department] = (buckets[department] ?? 0) + lineTotal;
      }
      if (buckets.isEmpty) {
        buckets[fallbackDepartment] = total;
      }
      final bucketTotal = buckets.values.fold<int>(0, (sum, value) => sum + value);
      final single = buckets.length == 1;
      buckets.forEach((name, lineTotal) {
        final dept = departments.putIfAbsent(name, () => _DepartmentAgg(name));
        dept.orders++;
        dept.gross += single ? total : lineTotal;
        dept.net += single ? total : lineTotal;
        if (onCredit) {
          dept.creditInvoices++;
          final share = bucketTotal <= 0 ? 0 : ((due > 0 ? due : total - paid) * lineTotal / bucketTotal).round();
          final dueAmount = due > 0 ? due : (total - paid).clamp(0, total).toInt();
          dept.amountDue += single ? dueAmount : share;
        } else {
          dept.paidInvoices++;
        }
      });
    }

    final byMethod = <String, int>{};
    final paymentRows = payments.isNotEmpty ? payments : sales;
    for (final row in paymentRows) {
      final method = row['method']?.toString().trim().isNotEmpty == true ? row['method'].toString() : 'cash';
      final amount = payments.isNotEmpty ? syncAsInt(row['amount']) : syncAsInt(row['total']);
      byMethod[method] = (byMethod[method] ?? 0) + amount;
    }

    final heading = await _companyHeading();
    final config = TerminalConfigRepository.instance.config;
    final user = (session.openedByName ?? '').trim().isNotEmpty
        ? session.openedByName!.trim()
        : config.cashierName.trim();
    final top = productQty.entries.toList()
      ..sort((a, b) {
        final byQty = b.value.compareTo(a.value);
        return byQty != 0 ? byQty : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    return SessionPerformance(
      companyName: heading.name,
      website: heading.website,
      userName: user.isEmpty ? 'Caissier' : user,
      sessionCode: sessionCode,
      openedAt: session.openedAt,
      closedAt: session.closedAt,
      currency: AppConfig.currencyCode,
      stores: storeIds.isEmpty ? 1 : storeIds.length,
      orders: sales.length,
      gross: gross,
      paidInvoices: paidInvoices,
      collected: collected,
      creditInvoices: creditInvoices,
      outstanding: outstanding < 0 ? 0 : outstanding,
      departments: departments.values
          .map((dept) => SessionDepartmentStats(
                name: dept.name,
                orders: dept.orders,
                gross: dept.gross,
                paidInvoices: dept.paidInvoices,
                net: dept.net,
                creditInvoices: dept.creditInvoices,
                amountDue: dept.amountDue,
              ))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      payments: byMethod.entries
          .map((entry) => SessionPaymentLine(label: _paymentLabel(entry.key), amount: entry.value))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount)),
      topProducts: [
        for (final entry in top.take(5)) SessionProductQty(name: entry.key, quantity: entry.value),
      ],
    );
  }

  /// Active open shift for a cashier at a given store (user-owned, store-scoped).
  Future<CashRegisterSession?> openShiftForCashier(
    String cashierId, {
    String? storeId,
  }) async {
    await _releaseFinishedShifts();
    final mine = cashierId.trim();
    if (mine.isEmpty) return null;
    final store = (storeId ?? TerminalConfigRepository.instance.config.storeId).trim();

    final rows = await DataModelDaos.shifts.list(
      where: "lower(status) = ? AND (closed_at IS NULL OR closed_at = '') AND user_id = ?",
      whereArgs: ['open', mine],
      orderBy: 'opened_at DESC',
    );

    for (final row in rows) {
      final session = CashRegisterSession.fromJson(_sessionJson(row));
      if (!session.isOpen) continue;
      final rowStore = (row['store_id']?.toString() ?? '').trim();
      if (store.isNotEmpty) {
        if (rowStore == store) return session;
        // Legacy rows without store_id: accept if register belongs to this store.
        if (rowStore.isEmpty) {
          final registerId = (row['cash_register_id']?.toString() ?? '').trim();
          if (registerId.isEmpty) continue;
          final register = await DataModelDaos.cashRegisters.find(registerId);
          final regStore = (register?['store_id']?.toString() ?? '').trim();
          if (regStore == store || regStore.isEmpty) return session;
        }
        continue;
      }
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
    if (!config.canOpenShift) {
      throw Exception('Seul un caissier peut ouvrir un shift.');
    }
    final storeId = config.storeId.trim();
    final mine = await openShiftForCashier(config.cashierId, storeId: storeId);
    if (mine != null) {
      throw Exception(
        'You already have an open shift for this store. Close it before opening another.',
      );
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
      'store_id': storeId,
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
      'store_id': storeId,
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
      cashRegisterId: session.cashRegisterId,
      storeId: session.storeId,
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

  /// Lines stored with a local sale, used when reviewing an unpaid order.
  Future<List<({String name, int quantity, int unitPrice})>> linesForReference(String reference) async {
    final key = reference.trim();
    if (key.isEmpty) return const [];
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('sales', where: 'reference = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return const [];
    final saleId = rows.first['id']?.toString() ?? '';
    try {
      final decoded = jsonDecode(rows.first['payload_json']?.toString() ?? '{}');
      if (decoded is Map && decoded['items'] is List) {
        final lines = <({String name, int quantity, int unitPrice})>[];
        for (final raw in decoded['items'] as List) {
          if (raw is! Map) continue;
          final name = (raw['product_name'] ?? raw['name'] ?? 'Article').toString();
          final quantity = syncAsInt(raw['quantity']);
          final price = syncAsInt(raw['unit_price']);
          lines.add((name: name, quantity: quantity < 1 ? 1 : quantity, unitPrice: price));
        }
        if (lines.isNotEmpty) return lines;
      }
    } catch (_) {}
    if (saleId.isEmpty) return const [];
    final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    return [
      for (final row in items)
        (
          name: () {
            try {
              final decoded = jsonDecode(row['json']?.toString() ?? '{}');
              if (decoded is Map) {
                final name = (decoded['product_name'] ?? decoded['name'])?.toString().trim() ?? '';
                if (name.isNotEmpty) return name;
              }
            } catch (_) {}
            return 'Article';
          }(),
          quantity: syncAsInt(row['quantity']) < 1 ? 1 : syncAsInt(row['quantity']),
          unitPrice: syncAsInt(row['unit_price']),
        ),
    ];
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

  String _paymentLabel(String method) {
    final words = method.replaceAll('_', ' ').trim();
    if (words.isEmpty) return 'Cash';
    return words.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  Future<({String name, String website})> _companyHeading() async {
    final config = TerminalConfigRepository.instance.config;
    var name = config.brandName.trim();
    var website = '';
    try {
      final db = await LocalDatabase.instance.database;
      final rows = await db.query('organizations', columns: ['name', 'json'], limit: 1);
      if (rows.isNotEmpty) {
        final stored = rows.first['name']?.toString().trim() ?? '';
        if (name.isEmpty && stored.isNotEmpty) name = stored;
        final decoded = jsonDecode(rows.first['json']?.toString() ?? '{}');
        if (decoded is Map) {
          final trade = _firstText([decoded['trade_name'], decoded['name'], stored], '');
          final legal = _firstText([decoded['legal_name']], '');
          if (name.isEmpty) {
            name = [trade, if (legal.isNotEmpty && legal != trade) legal].where((part) => part.isNotEmpty).join(' ');
          }
          website = _firstText([decoded['website'], decoded['website_url'], decoded['url']], '');
        }
      }
    } catch (_) {}
    if (name.isEmpty) name = 'ITARA POS';
    if (website.isEmpty) website = 'www.nc-africa.com';
    return (name: name, website: website);
  }
}

class _StoreAgg {
  _StoreAgg(this.id, this.name);

  final String id;
  final String name;
  final lines = <String, _LineAgg>{};
}

class _DepartmentAgg {
  _DepartmentAgg(this.name);

  final String name;
  int orders = 0;
  int gross = 0;
  int paidInvoices = 0;
  int net = 0;
  int creditInvoices = 0;
  int amountDue = 0;
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
