/// Feature modules (Clean Architecture — mobile.md §15).
library;

export 'authentication/authentication.dart';
export 'cash_register/cash_register.dart';
export 'categories/categories.dart';
export 'customers/customers.dart';
export 'dashboard/dashboard.dart';
export 'devices/devices.dart';
export 'expenses/expenses.dart';
export 'inventory/inventory.dart';
export 'kitchen/kitchen.dart';
export 'notifications/notifications.dart';
export 'payments/payments.dart';
export 'pos/pos.dart';
export 'printers/printers.dart';
export 'products/products.dart';
export 'purchases/purchases.dart';
export 'reports/reports.dart';
export 'restaurant/restaurant.dart';
export 'sales/sales.dart';
export 'settings/settings.dart';
export 'shifts/shifts.dart' hide CashRegister, CashRegisterSession, MovementType;
export 'suppliers/suppliers.dart';
export 'synchronization/synchronization.dart';
export 'tables/tables.dart';
