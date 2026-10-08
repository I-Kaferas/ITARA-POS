import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/data/pin_auth_service.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/pin_login.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/presentation/bloc/authentication_bloc.dart';
import '../../features/customers/presentation/bloc/customer_bloc.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/devices/presentation/bloc/device_bloc.dart';
import '../../features/devices/presentation/bloc/master_connection_bloc.dart';
import '../../features/devices/presentation/bloc/master_discovery_bloc.dart';
import '../../features/devices/presentation/bloc/master_pairing_bloc.dart';
import '../../features/expenses/presentation/bloc/expense_bloc.dart';
import '../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../features/inventory/presentation/bloc/stock_count_bloc.dart';
import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../../features/pos/presentation/bloc/cart_bloc.dart';
import '../../features/pos/presentation/bloc/category_bloc.dart';
import '../../features/pos/presentation/bloc/checkout_bloc.dart';
import '../../features/pos/presentation/bloc/payment_bloc.dart';
import '../../features/pos/presentation/bloc/product_bloc.dart';
import '../../features/printers/presentation/bloc/print_queue_bloc.dart';
import '../../features/printers/presentation/bloc/printer_configuration_bloc.dart';
import '../../features/printers/presentation/bloc/printer_connection_bloc.dart';
import '../../features/printers/presentation/bloc/printer_discovery_bloc.dart';
import '../../features/printers/presentation/bloc/printer_routing_bloc.dart';
import '../../features/purchases/presentation/bloc/purchase_bloc.dart';
import '../../features/kitchen/presentation/bloc/kitchen_bloc.dart';
import '../../features/restaurant/presentation/bloc/restaurant_bloc.dart';
import '../../features/restaurant/presentation/bloc/restaurant_order_bloc.dart';
import '../../features/restaurant/presentation/bloc/table_bloc.dart';
import '../../features/sales/presentation/bloc/refund_bloc.dart';
import '../../features/sales/presentation/bloc/sales_bloc.dart';
import '../../features/cash_register/presentation/bloc/cash_register_bloc.dart';
import '../../features/shifts/presentation/bloc/shift_bloc.dart';
import '../../features/suppliers/presentation/bloc/supplier_bloc.dart';
import '../../features/sync/presentation/bloc/cloud_sync_bloc.dart';
import '../../features/sync/presentation/bloc/conflict_resolution_bloc.dart';
import '../../features/sync/presentation/bloc/local_sync_bloc.dart';
import '../../sync/cloud/cloud_sync_engine.dart';
import '../../sync/device_registry.dart';
import '../../sync/local_master_discovery.dart';
import '../../sync/local_master_server.dart';
import '../../sync/local_realtime.dart';
import '../../sync/master_config_store.dart';
import '../../sync/offline_store.dart';
import '../../sync/pairing_service.dart';
import '../../sync/sync_engine.dart';
import '../../sync/sync_queue.dart';
import '../api/api_client.dart';
import '../config/settings_bloc.dart';
import '../config/terminal_bloc.dart';
import '../config/terminal_config_repository.dart';
import '../config/terminal_repository.dart';
import '../config/terminal_repository_impl.dart';
import '../database/database_module.dart';
import '../logging/app_logger.dart';
import '../logging/diagnostic_exporter.dart';
import '../logging/log_store.dart';
import '../network/network_bloc.dart';
import '../printer/printer.dart';
import '../security/token_store.dart';
import '../storage/local_storage.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_cubit.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  if (sl.isRegistered<AppLogger>()) return;

  sl.registerLazySingleton<AppLogger>(() => AppLogger());
  sl.registerLazySingleton<TokenStore>(() => TokenStore.instance);
  sl.registerLazySingleton<LocalStorage>(() => LocalStorage.instance);

  await LocalDatabase.ensureInitialized();
  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase.instance);
  sl.registerLazySingleton<LogStore>(() => LogStore(database: sl<LocalDatabase>()));
  sl<AppLogger>().attachStore(sl<LogStore>());
  sl.registerLazySingleton<DiagnosticExporter>(
    () => DiagnosticExporter(
      logStore: sl<LogStore>(),
      configRepository: TerminalConfigRepository.instance,
      database: sl<LocalDatabase>(),
    ),
  );

  sl.registerLazySingleton<TerminalConfigRepository>(
    () => TerminalConfigRepository.instance,
  );
  sl.registerLazySingleton<TerminalRepository>(
    () => TerminalRepositoryImpl(sl<TerminalConfigRepository>()),
  );

  sl.registerLazySingleton<ThemeController>(() => ThemeController.instance);

  sl.registerLazySingleton<http.Client>(() => http.Client());
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(client: sl<http.Client>()),
  );
  sl.registerLazySingleton<PinAuthService>(
    () => PinAuthService(client: sl<http.Client>()),
  );

  sl.registerLazySingleton<OfflineStore>(() => OfflineStore.instance);
  sl.registerLazySingleton<SyncEngine>(() => SyncEngine.instance);
  sl.registerLazySingleton<SyncQueue>(
    () => SyncQueue(store: sl(), engine: sl()),
  );
  sl.registerLazySingleton<LocalMasterServer>(() => LocalMasterServer.instance);
  sl.registerLazySingleton<LocalMasterDiscovery>(
    () => LocalMasterDiscovery.instance,
  );
  sl.registerLazySingleton<LocalRealtimeHub>(() => LocalRealtimeHub.instance);
  sl.registerLazySingleton<LocalRealtimeClient>(
    () => LocalRealtimeClient.instance,
  );
  sl.registerLazySingleton<MasterConfigStore>(() => MasterConfigStore.instance);
  sl.registerLazySingleton<PrintSpooler>(() => PrintSpooler.instance);
  sl.registerLazySingleton<MasterPrintServer>(() => MasterPrintServer.instance);
  sl.registerLazySingleton<PrinterService>(() => PrinterService.instance);
  sl.registerLazySingleton<PrinterManager>(() => PrinterManager.instance);
  sl.registerLazySingleton<PrintQueue>(() => PrintQueue.instance);
  sl.registerLazySingleton<PrinterRouter>(() => PrinterRouter.instance);
  sl.registerLazySingleton<DeviceRegistry>(() => DeviceRegistry.instance);
  sl.registerLazySingleton<PairingService>(() => PairingService.instance);

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      pinAuthService: sl(),
      configRepository: sl(),
      logger: sl(),
    ),
  );
  sl.registerLazySingleton<PinLogin>(() => PinLogin(sl()));
  sl.registerLazySingleton<SignOut>(() => SignOut(sl()));

  sl.registerFactory<AuthenticationBloc>(
    () => AuthenticationBloc(
      pinLogin: sl(),
      signOut: sl(),
      authRepository: sl(),
    ),
  );

  sl.registerLazySingleton<TerminalBloc>(
    () => TerminalBloc(
      repository: sl(),
      configRepository: sl(),
      logger: sl(),
    ),
  );
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit(sl()));
  sl.registerLazySingleton<SettingsBloc>(
    () => SettingsBloc(
      terminalBloc: sl(),
      themeController: sl(),
    ),
  );
  sl.registerLazySingleton<NetworkBloc>(
    () => NetworkBloc(
      syncEngine: sl(),
      discovery: sl(),
      masterServer: sl(),
      configRepository: sl(),
      logger: sl(),
    ),
  );

  sl.registerLazySingleton<MasterDiscoveryBloc>(
    () => MasterDiscoveryBloc(sl()),
  );
  sl.registerLazySingleton<MasterConnectionBloc>(
    () => MasterConnectionBloc(
      syncEngine: sl(),
      masterServer: sl(),
      configRepository: sl(),
    ),
  );
  sl.registerLazySingleton<MasterPairingBloc>(
    () => MasterPairingBloc(sl()),
  );
  sl.registerLazySingleton<DeviceBloc>(
    () => DeviceBloc(registry: sl(), masterServer: sl()),
  );

  // App-wide §16 blocs
  sl.registerLazySingleton<NotificationBloc>(() => NotificationBloc());
  sl.registerLazySingleton<LocalSyncBloc>(() => LocalSyncBloc());
  sl.registerLazySingleton<CloudSyncEngine>(() => CloudSyncEngine.instance);
  sl.registerLazySingleton<CloudSyncBloc>(
    () => CloudSyncBloc(engine: sl()),
  );
  sl.registerLazySingleton<ConflictResolutionBloc>(() => ConflictResolutionBloc());
  sl.registerLazySingleton<PrintQueueBloc>(
    () => PrintQueueBloc(spooler: sl()),
  );
  sl.registerLazySingleton<DashboardBloc>(() => DashboardBloc());

  // Screen-scoped factories
  sl.registerFactory<ProductBloc>(() => ProductBloc());
  sl.registerFactory<CategoryBloc>(() => CategoryBloc());
  sl.registerFactory<CartBloc>(() => CartBloc());
  sl.registerFactory<CheckoutBloc>(() => CheckoutBloc());
  sl.registerFactory<PaymentBloc>(() => PaymentBloc());
  sl.registerFactory<CustomerBloc>(() => CustomerBloc());
  sl.registerFactory<InventoryBloc>(() => InventoryBloc());
  sl.registerFactory<StockCountBloc>(() => StockCountBloc());
  sl.registerFactory<PurchaseBloc>(() => PurchaseBloc());
  sl.registerFactory<SupplierBloc>(() => SupplierBloc());
  sl.registerFactory<CashRegisterBloc>(() => CashRegisterBloc());
  sl.registerFactory<ShiftBloc>(() => ShiftBloc());
  sl.registerFactory<SalesBloc>(() => SalesBloc());
  sl.registerFactory<RefundBloc>(() => RefundBloc());
  sl.registerFactory<ExpenseBloc>(() => ExpenseBloc());
  sl.registerFactory<RestaurantBloc>(() => RestaurantBloc());
  sl.registerFactory<TableBloc>(() => TableBloc());
  sl.registerFactory<RestaurantOrderBloc>(() => RestaurantOrderBloc());
  sl.registerFactory<KitchenBloc>(() => KitchenBloc());
  sl.registerFactory<PrinterDiscoveryBloc>(() => PrinterDiscoveryBloc());
  sl.registerFactory<PrinterConnectionBloc>(() => PrinterConnectionBloc());
  sl.registerFactory<PrinterConfigurationBloc>(() => PrinterConfigurationBloc());
  sl.registerFactory<PrinterRoutingBloc>(() => PrinterRoutingBloc());

  sl<AppLogger>().info('Dependencies configured', tag: 'di');
  sl<AppLogger>().sync('Log store attached');
}
