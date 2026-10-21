import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounting/presentation/accounting_screen.dart';
import '../../features/auth/presentation/admin_login_screen.dart';
import '../../features/auth/presentation/pin_login_screen.dart';
import '../../features/barcode/presentation/barcode_hub_screen.dart';
import '../../features/customers/presentation/customer_account_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/home/presentation/pos_menu_screen.dart';
import '../../features/hub/presentation/hub_screen.dart';
import '../../features/hub/presentation/master_configuration_screen.dart';
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
import '../../features/settings/presentation/cashier_settings_screen.dart';
import '../../features/settings/presentation/configuration_screen.dart';
import '../../features/setup/presentation/setup_screen.dart';
import '../../features/setup/presentation/slave_setup_wizard.dart';
import '../../features/cash_register/presentation/cash_register_screen.dart';
import '../../features/shifts/presentation/shifts_screen.dart';
import '../../features/stock/presentation/stock_screen.dart';
import '../../features/sync/presentation/sync_screen.dart';
import '../../sync/local_master_server.dart';
import '../../sync/sync_engine.dart';
import '../../features/auth/presentation/auth_gate_screen.dart';
import '../../features/onboarding/onboarding_gate.dart';
import '../../features/onboarding/presentation/onboarding_finish_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/product_showcase_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../config/terminal_config_repository.dart';
import '../di/service_locator.dart';
import 'app_routes.dart';
import 'app_shell.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static GoRouter? _router;

  static GoRouter create() {
    final sync = sl.isRegistered<SyncEngine>()
        ? sl<SyncEngine>()
        : SyncEngine.instance;
    final master = sl.isRegistered<LocalMasterServer>()
        ? sl<LocalMasterServer>()
        : LocalMasterServer.instance;
    sync.start();
    master.startIfMaster();
    final configRepo = sl.isRegistered<TerminalConfigRepository>()
        ? sl<TerminalConfigRepository>()
        : TerminalConfigRepository.instance;
    return _router ??= GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.pos,
      refreshListenable: Listenable.merge([
        configRepo,
        OnboardingGate.instance,
      ]),
      redirect: (context, state) {
        final repo = configRepo;
        if (!repo.isLoaded) return null;

        final location = state.matchedLocation;
        final replay = state.uri.queryParameters['replay'] == '1';
        final isTour =
            location == AppRoutes.welcome ||
            location == AppRoutes.onboarding ||
            location == AppRoutes.showcase ||
            location == AppRoutes.onboardingFinish;
        if (!OnboardingGate.instance.seen && !isTour) return AppRoutes.welcome;
        if (isTour && (!OnboardingGate.instance.seen || replay)) return null;
        final isAdminLogin = location == AppRoutes.adminLogin;
        final isSetup =
            location == AppRoutes.setup || location == AppRoutes.slaveSetup;
        final isConfig = location == AppRoutes.configuration ||
            location == AppRoutes.hub ||
            location == AppRoutes.masterConfiguration;
        final isPrefs = location == AppRoutes.cashierSettings;
        final isPin = location == AppRoutes.pin;
        final hasToken = repo.config.authToken.trim().isNotEmpty;
        final signedIn = repo.config.isSignedIn && hasToken;

        if (!repo.isConfigured && !signedIn && !isAdminLogin) {
          return AppRoutes.adminLogin;
        }
        if (!repo.isConfigured && signedIn && !isSetup && !isConfig && !isPrefs) {
          return AppRoutes.cashierSettings;
        }
        if (!repo.isConfigured && isAdminLogin && signedIn) {
          return AppRoutes.cashierSettings;
        }
        if (!repo.isConfigured) return null;

        if (location == AppRoutes.configuration) {
          AuthNavigation.openSettings = false;
          return AppRoutes.pos;
        }
        if (!signedIn && !isPin && !isAdminLogin) return AppRoutes.pin;
        // Operational menus require a linked company (tenant + brand/profile).
        final onOperationalMenu = location == AppRoutes.dashboard ||
            location == AppRoutes.pos ||
            (location.startsWith('${AppRoutes.dashboard}/') &&
                !location.startsWith(AppRoutes.kitchen)) ||
            location.startsWith(AppRoutes.orders) ||
            location.startsWith(AppRoutes.shifts);
        if (signedIn && !repo.isCompanyConfigured && onOperationalMenu) {
          return AppRoutes.cashierSettings;
        }
        if (signedIn &&
            AppRoutes.isConfiguration(location) &&
            !repo.config.isAdmin &&
            repo.isCompanyConfigured) {
          return AppRoutes.pos;
        }
        if (signedIn && repo.isConfigured && AuthNavigation.openSettings) {
          if (location == AppRoutes.cashierSettings) {
            AuthNavigation.openSettings = false;
            return null;
          }
          return AppRoutes.cashierSettings;
        }
        if (signedIn && (isSetup || isPin || isAdminLogin)) {
          return repo.isCompanyConfigured ? AppRoutes.pos : AppRoutes.cashierSettings;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.welcome,
          builder: (_, _) => const WelcomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.showcase,
          builder: (_, _) => const ProductShowcaseScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboardingFinish,
          builder: (_, _) => const OnboardingFinishScreen(),
        ),
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
        StatefulShellRoute(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          navigatorContainerBuilder: (context, navigationShell, children) =>
              ResettingShellBranches(currentIndex: navigationShell.currentIndex, children: children),
          branches: [
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
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.reservations,
                  builder: (_, __) => const PosReservationsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.stock,
                  builder: (_, __) => const StockScreen(),
                ),
              ],
            ),
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
                  path: AppRoutes.cashierSettings,
                  builder: (_, __) => const CashierSettingsScreen(),
                ),
                GoRoute(
                  path: AppRoutes.hub,
                  builder: (_, __) => const HubScreen(),
                ),
                GoRoute(
                  path: AppRoutes.masterConfiguration,
                  builder: (_, state) => MasterConfigurationScreen(
                    initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
                  ),
                ),
                GoRoute(
                  path: AppRoutes.configuration,
                  builder: (_, state) {
                    final section = int.tryParse(state.uri.queryParameters['section'] ?? '') ?? 0;
                    return ConfigurationScreen(
                      key: ValueKey('config-$section'),
                      initialSection: section,
                    );
                  },
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

/// Only the visible branch stays mounted, so a screen starts fresh each time
/// it is reopened. The cashier branch is kept alive because the open sale
/// lives in its state and is not persisted until it is held or paid.
class ResettingShellBranches extends StatelessWidget {
  const ResettingShellBranches({super.key, required this.currentIndex, required this.children});

  static const _posBranch = 0;

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: currentIndex,
      children: [
        for (var i = 0; i < children.length; i++)
          if (i == currentIndex || i == _posBranch)
            TickerMode(enabled: i == currentIndex, child: children[i])
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
