import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/terminal_config_repository.dart';
import '../../features/accounting/presentation/accounting_screen.dart';
import '../../features/auth/presentation/pin_login_screen.dart';
import '../../features/barcode/presentation/barcode_hub_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/customers/presentation/customer_account_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/hospitality/presentation/hospitality_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/production/presentation/production_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/services/presentation/services_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/settings/presentation/configuration_screen.dart';
import '../../features/setup/presentation/setup_screen.dart';
import '../../features/shifts/presentation/shifts_screen.dart';
import '../../features/sync/presentation/sync_screen.dart';
import '../../sync/local_master_server.dart';
import '../../sync/sync_engine.dart';
import 'app_routes.dart';
import 'app_shell.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter create() {
    SyncEngine.instance.start();
    LocalMasterServer.instance.startIfMaster();
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.dashboard,
      refreshListenable: TerminalConfigRepository.instance,
      redirect: (context, state) {
        final repo = TerminalConfigRepository.instance;
        if (!repo.isLoaded) return null;

        final location = state.matchedLocation;
        final isSetup = location == AppRoutes.setup;
        final isPin = location == AppRoutes.pin;

        if (!repo.isConfigured && !isSetup) return AppRoutes.setup;
        if (!repo.isConfigured) return null;

        if (!repo.config.isSignedIn && !isPin) return AppRoutes.pin;
        if (repo.config.isSignedIn && (isSetup || isPin)) return AppRoutes.dashboard;
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.setup,
          builder: (_, __) => const SetupScreen(),
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
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.dashboard,
                  builder: (_, __) => DashboardScreen(
                    onNavigate: (index) => _goToTab(index),
                    onConfigurationTap: () => _rootNavigatorKey.currentContext?.go(AppRoutes.configuration),
                  ),
                  routes: [
                    GoRoute(
                      path: 'hospitality',
                      builder: (_, __) => const HospitalityScreen(),
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
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.pos,
                  builder: (_, __) => const PosScreen(embedded: true),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.orders,
                  builder: (_, __) => const OrdersScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.shifts,
                  builder: (_, __) => const ShiftsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
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

  static void _goToTab(int index) {
    final context = _rootNavigatorKey.currentContext;
    if (context == null) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
      case 1:
        context.go(AppRoutes.pos);
      case 2:
        context.go(AppRoutes.orders);
      case 3:
        context.go(AppRoutes.shifts);
      case 4:
        context.go(AppRoutes.configuration);
    }
  }
}
