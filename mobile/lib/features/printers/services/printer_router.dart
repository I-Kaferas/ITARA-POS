import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/local_database.dart';
import '../domain/print_group.dart';
import '../domain/print_job.dart';
import '../domain/print_route.dart';
import '../domain/printer.dart';
import 'printer_manager.dart';

class PrinterRouteDecision {
  const PrinterRouteDecision({
    required this.printers,
    required this.group,
    this.matchedRoute,
    this.reason = '',
  });

  final List<Printer> printers;
  final PrintGroup group;
  final PrintRoute? matchedRoute;
  final String reason;

  Printer? get primary => printers.isEmpty ? null : printers.first;
}

/// Line context used to split a sale across kitchen / bar / cashier printers.
class PrintRouteLineRef {
  const PrintRouteLineRef({
    this.productId = '',
    this.categoryId = '',
    this.productKey = '',
    this.categoryKey = '',
  });

  final String productId;
  final String categoryId;
  /// Optional SKU / slug for product routes (e.g. `pizza-margherita`).
  final String productKey;
  /// Optional category name / slug (e.g. `drink`, `pizza`).
  final String categoryKey;
}

/// Resolves which printer(s) should handle a job (mobile.md §37 / §40 / §41).
///
/// Precedence (spec §40):
/// ```text
/// Product → Printer  >  Category → Printer  >  Document → Printer
/// ```
class PrinterRouter {
  PrinterRouter({
    PrinterManager? manager,
    Future<Database> Function()? database,
  })  : _manager = manager ?? PrinterManager.instance,
        _database = database ?? (() => LocalDatabase.instance.database);

  final PrinterManager _manager;
  final Future<Database> Function() _database;

  static final PrinterRouter instance = PrinterRouter();

  /// Default document → group map used when no explicit route exists.
  static const Map<String, PrintGroup> documentDefaults = {
    'receipt': PrintGroup.cashier,
    'invoice': PrintGroup.cashier,
    'z_report': PrintGroup.cashier,
    'kitchen': PrintGroup.kitchen,
    'bar': PrintGroup.bar,
    'ticket': PrintGroup.cashier,
    'dessert': PrintGroup.dessert,
  };

  /// Product beats category beats document (lower = earlier).
  static int kindRank(PrintRouteKind kind) => switch (kind) {
        PrintRouteKind.product => 0,
        PrintRouteKind.category => 1,
        PrintRouteKind.document => 2,
      };

  Future<List<PrintRoute>> listRoutes() async {
    final db = await _database();
    final rows = await db.query('print_routes', orderBy: 'priority ASC, kind ASC');
    final routes = rows.map(PrintRoute.fromRow).toList();
    routes.sort(_compareRoutes);
    return routes;
  }

  Future<PrintRoute> upsertRoute(PrintRoute route) async {
    final db = await _database();
    final saved = PrintRoute(
      id: route.id.isEmpty ? const Uuid().v4() : route.id,
      kind: route.kind,
      matchKey: route.matchKey.trim(),
      group: route.group,
      printerId: route.printerId,
      enabled: route.enabled,
      priority: route.priority,
      label: route.label,
    );
    await db.insert(
      'print_routes',
      saved.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return saved;
  }

  Future<void> deleteRoute(String id) async {
    final db = await _database();
    await db.delete('print_routes', where: 'id = ?', whereArgs: [id]);
  }

  /// Seeds §40 examples when the table is empty:
  /// Drink → Bar, Pizza → Kitchen, Receipt → Cashier.
  Future<void> seedDefaultRoutes({bool force = false}) async {
    final existing = await listRoutes();
    if (existing.isNotEmpty && !force) return;
    const defaults = <PrintRoute>[
      PrintRoute(
        id: 'route-receipt',
        kind: PrintRouteKind.document,
        matchKey: 'receipt',
        group: PrintGroup.cashier,
        priority: 100,
        label: 'Receipt → Cashier Printer',
      ),
      PrintRoute(
        id: 'route-invoice',
        kind: PrintRouteKind.document,
        matchKey: 'invoice',
        group: PrintGroup.cashier,
        priority: 100,
        label: 'Invoice → Cashier Printer',
      ),
      PrintRoute(
        id: 'route-kitchen-doc',
        kind: PrintRouteKind.document,
        matchKey: 'kitchen',
        group: PrintGroup.kitchen,
        priority: 100,
        label: 'Kitchen ticket → Kitchen Printer',
      ),
      PrintRoute(
        id: 'route-bar-doc',
        kind: PrintRouteKind.document,
        matchKey: 'bar',
        group: PrintGroup.bar,
        priority: 100,
        label: 'Bar ticket → Bar Printer',
      ),
      PrintRoute(
        id: 'route-cat-drink',
        kind: PrintRouteKind.category,
        matchKey: 'drink',
        group: PrintGroup.bar,
        priority: 10,
        label: 'Drink → Bar Printer',
      ),
      PrintRoute(
        id: 'route-cat-boisson',
        kind: PrintRouteKind.category,
        matchKey: 'boisson',
        group: PrintGroup.bar,
        priority: 10,
        label: 'Boisson → Bar Printer',
      ),
      PrintRoute(
        id: 'route-cat-pizza',
        kind: PrintRouteKind.category,
        matchKey: 'pizza',
        group: PrintGroup.kitchen,
        priority: 10,
        label: 'Pizza → Kitchen Printer',
      ),
      PrintRoute(
        id: 'route-cat-food',
        kind: PrintRouteKind.category,
        matchKey: 'food',
        group: PrintGroup.kitchen,
        priority: 20,
        label: 'Food → Kitchen Printer',
      ),
    ];
    for (final route in defaults) {
      await upsertRoute(route);
    }
  }

  /// Resolve ordered failover candidates for a queued [PrintJob].
  Future<PrinterRouteDecision> resolve(PrintJob job) {
    return resolveContext(
      documentType: job.documentType,
      categoryId: job.categoryId,
      productId: job.productId,
      printerId: job.printerId,
      fallbackGroup: job.group,
    );
  }

  /// Resolve Category / Product / Document → Printer (mobile.md §40).
  Future<PrinterRouteDecision> resolveContext({
    String documentType = 'receipt',
    String categoryId = '',
    String productId = '',
    String categoryKey = '',
    String productKey = '',
    String printerId = '',
    PrintGroup fallbackGroup = PrintGroup.cashier,
  }) async {
    if (printerId.isNotEmpty) {
      final pinned = await _manager.findById(printerId);
      if (pinned != null && pinned.enabled) {
        return PrinterRouteDecision(
          printers: [pinned],
          group: pinned.group,
          reason: 'printer_id',
        );
      }
    }

    final routes = await listRoutes();
    final matched = pickBestRoute(
      routes: routes,
      documentType: documentType,
      categoryId: categoryId,
      productId: productId,
      categoryKey: categoryKey,
      productKey: productKey,
    );

    final group = matched?.group ??
        documentDefaults[documentType.toLowerCase()] ??
        fallbackGroup;

    if (matched?.printerId.isNotEmpty == true) {
      final pinned = await _manager.findById(matched!.printerId);
      if (pinned != null && pinned.enabled) {
        final rest = await _manager.forGroup(group, readyOnly: false);
        final failover = rest.where((p) => p.id != pinned.id).toList();
        return PrinterRouteDecision(
          printers: [pinned, ...failover],
          group: group,
          matchedRoute: matched,
          reason: 'route_printer',
        );
      }
    }

    final candidates = await _manager.forGroup(group, readyOnly: false);
    final ready = candidates.where((p) => p.isReady).toList();
    final offline = candidates.where((p) => !p.isReady).toList();

    return PrinterRouteDecision(
      printers: [...ready, ...offline],
      group: group,
      matchedRoute: matched,
      reason: matched != null ? 'route_group' : 'group_default',
    );
  }

  /// Split cart / ticket lines by destination print group (§40 example).
  Future<Map<PrintGroup, List<T>>> partitionByRoute<T>({
    required List<T> lines,
    required PrintRouteLineRef Function(T line) refOf,
    String documentType = 'kitchen',
    PrintGroup fallbackGroup = PrintGroup.kitchen,
  }) async {
    final routes = await listRoutes();
    final buckets = <PrintGroup, List<T>>{};
    for (final line in lines) {
      final ref = refOf(line);
      final matched = pickBestRoute(
        routes: routes,
        documentType: documentType,
        categoryId: ref.categoryId,
        productId: ref.productId,
        categoryKey: ref.categoryKey,
        productKey: ref.productKey,
      );
      final group = matched?.group ??
          documentDefaults[documentType.toLowerCase()] ??
          fallbackGroup;
      buckets.putIfAbsent(group, () => <T>[]).add(line);
    }
    return buckets;
  }

  /// Pure route picker (unit-testable).
  @visibleForTesting
  static PrintRoute? pickBestRoute({
    required List<PrintRoute> routes,
    required String documentType,
    String categoryId = '',
    String productId = '',
    String categoryKey = '',
    String productKey = '',
  }) {
    final enabled = routes.where((r) => r.enabled).toList()..sort(_compareRoutes);
    for (final route in enabled) {
      if (_matches(
        route,
        documentType: documentType,
        categoryId: categoryId,
        productId: productId,
        categoryKey: categoryKey,
        productKey: productKey,
      )) {
        return route;
      }
    }
    return null;
  }

  static int _compareRoutes(PrintRoute a, PrintRoute b) {
    final byKind = kindRank(a.kind).compareTo(kindRank(b.kind));
    if (byKind != 0) return byKind;
    return a.priority.compareTo(b.priority);
  }

  static bool _matches(
    PrintRoute route, {
    required String documentType,
    String categoryId = '',
    String productId = '',
    String categoryKey = '',
    String productKey = '',
  }) {
    final key = route.matchKey.trim();
    if (key.isEmpty) return false;
    final keyLower = key.toLowerCase();

    switch (route.kind) {
      case PrintRouteKind.product:
        if (productId.isNotEmpty && key == productId) return true;
        if (productKey.isNotEmpty && keyLower == productKey.trim().toLowerCase()) {
          return true;
        }
        return false;
      case PrintRouteKind.category:
        if (categoryId.isNotEmpty && key == categoryId) return true;
        if (categoryKey.isNotEmpty && keyLower == categoryKey.trim().toLowerCase()) {
          return true;
        }
        return false;
      case PrintRouteKind.document:
        return keyLower == documentType.trim().toLowerCase();
    }
  }
}
