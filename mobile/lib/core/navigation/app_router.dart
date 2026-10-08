import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounting/presentation/accounting_screen.dart';
import '../../features/auth/presentation/admin_login_screen.dart';
import '../../features/auth/presentation/pin_login_screen.dart';
import '../../features/barcode/presentation/barcode_hub_screen.dart';
import '../../features/customers/presentation/customer_account_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/home/presentation/pos_menu_screen.dart';
import '../../features/hospitality/presentation/hospitality_screen.dart';
import '../../features/kitchen/presentation/kitchen_display_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/pos/presentation/pos_overview_screen.dart';
import '../../features/pos/presentation/pos_reservations_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/production/presentation/production_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/sales/presentation/returns_screen.dart';
import '../../features/sales/presentation/sale_detail_screen.dart';
import '../../features/services/presentation/services_screen.dart';
import '../../features/settings/presentation/configuration_screen.dart';
import '../../features/setup/presentation/setup_screen.dart';
import '../../features/setup/presentation/slave_setup_wizard.dart';
import '../../features/cash_register/presentation/cash_register_screen.dart';
import '../../features/shifts/presentation/shifts_screen.dart';
import '../../features/stock/presentation/stock_screen.dart';
import '../../features/sync/presentation/sync_screen.dart';
import '../../sync/local_master_server.dart';
import '../../sync/sync_engine.dart';
import '../config/terminal_config_repository.dart';
import '../di/service_locator.dart';
import 'app_routes.dart';
import 'app_shell.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static GoRouter? _router;

  static GoRouter create() {
    final sync = sl.isRegistered<SyncEngine>() ? sl<SyncEngine>() : SyncEngine.instance;
    final master =
        sl.isRegistered<LocalMasterServer>() ? sl<LocalMasterServer>() : LocalMasterServer.instance;
    sync.start();
    master.startIfMaster();
    final configRepo = sl.isRegistered<TerminalConfigRepository>()
        ? sl<TerminalConfigRepository>()
        : TerminalConfigRepository.instance;
    return _router ??= GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.pos,
      refreshListenable: configRepo,
      redirect: (context, state) {
        final repo = configRepo;
        if (!repo.isLoaded) return null;

        final location = state.matchedLocation;
        final isAdminLogin = location == AppRoutes.adminLogin;
        final isSetup = location == AppRoutes.setup ||
            location == AppRoutes.slaveSetup;
        final isPin = location == AppRoutes.pin;
        final hasToken = repo.config.authToken.trim().isNotEmpty;
        final signedIn = repo.config.isSignedIn && hasToken;

        if (!repo.isConfigured && !signedIn && !isAdminLogin) {
          return AppRoutes.adminLogin;
        }
        if (!repo.isConfigured && signedIn && !isSetup) {
          return AppRoutes.setup;
        }
        if (!repo.isConfigured && isAdminLogin && signedIn) {
          return AppRoutes.setup;
        }
        if (!repo.isConfigured) return null;

        if (!signedIn && !isPin && !isAdminLogin) return AppRoutes.pin;
        if (signedIn && (isSetup || isPin || isAdminLogin)) return AppRoutes.pos;
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.adminLogin,
          builder: (_, __) => const AdminLoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.setup,
          builder: (_, __) => const SetupScreen(),
        ),
        GoRoute(
          path: AppRoutes.slaveSetup,
          builder: (_, __) => const SlaveSetupWizard(),
        ),
        GoRoute(
          path: AppRoutes.pin,
          builder: (_, __) => const PinLoginScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            // 0 — POS
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.pos,
                  builder: (_, __) => const PosScreen(embedded: true),
                ),
              ],
            ),
            // 1 — Sales
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.orders,
                  builder: (_, __) => const OrdersScreen(),
                  routes: [
                    GoRoute(
                      path: 'sale/:id',
                      builder: (_, state) => SaleDetailScreen(
                        saleId: state.pathParameters['id'] ?? '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // 2 — Tables
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.reservations,
                  builder: (_, __) => const PosReservationsScreen(),
                ),
              ],
            ),
            // 3 — Stock
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.stock,
                  builder: (_, __) => const StockScreen(),
                ),
              ],
            ),
            // 4 — Menu + secondary modules
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.menu,
                  builder: (_, __) => const PosMenuScreen(),
                ),
                GoRoute(
                  path: AppRoutes.dashboard,
                  builder: (_, __) => const PosOverviewScreen(),
                  routes: [
                    GoRoute(
                      path: 'hospitality',
                      builder: (_, __) => const HospitalityScreen(),
                    ),
                    GoRoute(
                      path: 'kitchen',
                      builder: (_, __) => const KitchenDisplayScreen(),
                    ),
                    GoRoute(
                      path: 'services',
                      builder: (_, __) => const ServicesScreen(),
                    ),
                    GoRoute(
                      path: 'production',
                      builder: (_, __) => const ProductionScreen(),
                    ),
                    GoRoute(
                      path: 'accounting',
                      builder: (_, __) => const AccountingScreen(),
                    ),
                    GoRoute(
                      path: 'reports',
                      builder: (_, __) => const ReportsScreen(),
                    ),
                    GoRoute(
                      path: 'notifications',
                      builder: (_, __) => const NotificationsScreen(),
                    ),
                    GoRoute(
                      path: 'customer-account',
                      builder: (_, __) => const CustomerAccountScreen(),
                    ),
                    GoRoute(
                      path: 'expenses',
                      builder: (_, __) => const ExpensesScreen(),
                    ),
                    GoRoute(
                      path: 'barcode',
                      builder: (_, __) => const BarcodeHubScreen(),
                    ),
                    GoRoute(
                      path: 'sync',
                      builder: (_, __) => const SyncScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: AppRoutes.returns,
                  builder: (_, __) => const ReturnsScreen(),
                ),
                GoRoute(
                  path: AppRoutes.shifts,
                  builder: (_, __) => const ShiftsScreen(),
                ),
                GoRoute(
                  path: AppRoutes.cashRegister,
                  builder: (_, __) => const CashRegisterScreen(),
                ),
                GoRoute(
                  path: AppRoutes.configuration,
                  builder: (_, __) => const ConfigurationScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static void goToTab(int index) {
    final context = _rootNavigatorKey.currentContext;
    if (context == null) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.pos);
      case 1:
        context.go(AppRoutes.orders);
      case 2:
        context.go(AppRoutes.reservations);
      case 3:
        context.go(AppRoutes.stock);
      case 4:
        context.go(AppRoutes.menu);
    }
  }
}
