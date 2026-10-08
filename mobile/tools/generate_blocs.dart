import 'dart:io';

typedef Spec = ({String dir, String file, String className});

final specs = <Spec>[
  (dir: 'features/dashboard/presentation/bloc', file: 'dashboard', className: 'Dashboard'),
  (dir: 'features/pos/presentation/bloc', file: 'product', className: 'Product'),
  (dir: 'features/pos/presentation/bloc', file: 'category', className: 'Category'),
  (dir: 'features/pos/presentation/bloc', file: 'cart', className: 'Cart'),
  (dir: 'features/pos/presentation/bloc', file: 'checkout', className: 'Checkout'),
  (dir: 'features/pos/presentation/bloc', file: 'payment', className: 'Payment'),
  (dir: 'features/customers/presentation/bloc', file: 'customer', className: 'Customer'),
  (dir: 'features/inventory/presentation/bloc', file: 'inventory', className: 'Inventory'),
  (dir: 'features/inventory/presentation/bloc', file: 'stock_count', className: 'StockCount'),
  (dir: 'features/purchases/presentation/bloc', file: 'purchase', className: 'Purchase'),
  (dir: 'features/suppliers/presentation/bloc', file: 'supplier', className: 'Supplier'),
  (dir: 'features/shifts/presentation/bloc', file: 'cash_register', className: 'CashRegister'),
  (dir: 'features/shifts/presentation/bloc', file: 'shift', className: 'Shift'),
  (dir: 'features/sales/presentation/bloc', file: 'sales', className: 'Sales'),
  (dir: 'features/sales/presentation/bloc', file: 'refund', className: 'Refund'),
  (dir: 'features/expenses/presentation/bloc', file: 'expense', className: 'Expense'),
  (dir: 'features/restaurant/presentation/bloc', file: 'restaurant', className: 'Restaurant'),
  (dir: 'features/restaurant/presentation/bloc', file: 'table', className: 'Table'),
  (dir: 'features/restaurant/presentation/bloc', file: 'restaurant_order', className: 'RestaurantOrder'),
  (dir: 'features/restaurant/presentation/bloc', file: 'kitchen', className: 'Kitchen'),
  (dir: 'features/printers/presentation/bloc', file: 'printer_discovery', className: 'PrinterDiscovery'),
  (dir: 'features/printers/presentation/bloc', file: 'printer_connection', className: 'PrinterConnection'),
  (dir: 'features/printers/presentation/bloc', file: 'printer_configuration', className: 'PrinterConfiguration'),
  (dir: 'features/printers/presentation/bloc', file: 'printer_routing', className: 'PrinterRouting'),
  (dir: 'features/printers/presentation/bloc', file: 'print_queue', className: 'PrintQueue'),
  (dir: 'features/sync/presentation/bloc', file: 'local_sync', className: 'LocalSync'),
  (dir: 'features/sync/presentation/bloc', file: 'cloud_sync', className: 'CloudSync'),
  (dir: 'features/sync/presentation/bloc', file: 'conflict_resolution', className: 'ConflictResolution'),
  (dir: 'features/notifications/presentation/bloc', file: 'notification', className: 'Notification'),
];

void main() {
  final root = Directory('lib');
  for (final s in specs) {
    final dir = Directory('${root.path}/${s.dir}');
    dir.createSync(recursive: true);
    final blocPath = '${dir.path}/${s.file}_bloc.dart';
    if (File(blocPath).existsSync()) {
      stdout.writeln('skip ${s.className}Bloc');
      continue;
    }
    File(blocPath).writeAsStringSync('''
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part '${s.file}_event.dart';
part '${s.file}_state.dart';

class ${s.className}Bloc extends Bloc<${s.className}Event, ${s.className}State> {
  ${s.className}Bloc() : super(const ${s.className}State()) {
    on<${s.className}Started>(_onStarted);
    on<${s.className}Refreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    ${s.className}Started event,
    Emitter<${s.className}State> emit,
  ) async {
    emit(state.copyWith(status: ${s.className}Status.loading, clearError: true));
    emit(state.copyWith(status: ${s.className}Status.ready));
  }

  Future<void> _onRefreshed(
    ${s.className}Refreshed event,
    Emitter<${s.className}State> emit,
  ) async {
    add(const ${s.className}Started());
  }
}
''');
    File('${dir.path}/${s.file}_event.dart').writeAsStringSync('''
part of '${s.file}_bloc.dart';

sealed class ${s.className}Event extends Equatable {
  const ${s.className}Event();

  @override
  List<Object?> get props => const [];
}

final class ${s.className}Started extends ${s.className}Event {
  const ${s.className}Started();
}

final class ${s.className}Refreshed extends ${s.className}Event {
  const ${s.className}Refreshed();
}
''');
    File('${dir.path}/${s.file}_state.dart').writeAsStringSync('''
part of '${s.file}_bloc.dart';

enum ${s.className}Status { initial, loading, ready, failure }

final class ${s.className}State extends Equatable {
  const ${s.className}State({
    this.status = ${s.className}Status.initial,
    this.errorMessage,
  });

  final ${s.className}Status status;
  final String? errorMessage;

  bool get isLoading => status == ${s.className}Status.loading;

  ${s.className}State copyWith({
    ${s.className}Status? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ${s.className}State(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
''');
    stdout.writeln('created ${s.className}Bloc');
  }
}
