import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/settings_bloc.dart';
import 'core/config/terminal_bloc.dart';
import 'core/config/terminal_config_repository.dart';
import 'core/di/service_locator.dart';
import 'core/logging/app_logger.dart';
import 'core/navigation/app_router.dart';
import 'core/network/network_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'data/local/data_model_bootstrap.dart';
import 'features/auth/presentation/bloc/authentication_bloc.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/devices/presentation/bloc/device_bloc.dart';
import 'features/devices/presentation/bloc/master_connection_bloc.dart';
import 'features/devices/presentation/bloc/master_discovery_bloc.dart';
import 'features/devices/presentation/bloc/master_pairing_bloc.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'features/printers/presentation/bloc/print_queue_bloc.dart';
import 'features/sync/presentation/bloc/cloud_sync_bloc.dart';
import 'features/sync/presentation/bloc/conflict_resolution_bloc.dart';
import 'features/sync/presentation/bloc/local_sync_bloc.dart';
import 'sync/local_master_discovery.dart';
import 'sync/local_master_server.dart';
import 'sync/local_realtime.dart';
import 'sync/sync_engine.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await configureDependencies();
    await DataModelBootstrap.ensureDefaults();

    final logger = sl<AppLogger>();
    final terminal = sl<TerminalBloc>();
    final loaded = terminal.stream.firstWhere((s) => s.isLoaded);
    terminal.add(const TerminalLoadRequested());
    await loaded;
    await sl<ThemeCubit>().load();

    runApp(const PosApp());
    unawaited(_bootBackgroundServices(logger));
  }, (error, stack) {
    try {
      sl<AppLogger>().error(
        'Uncaught error',
        tag: 'app',
        error: error,
        stackTrace: stack,
      );
    } catch (_) {
      // ignore: avoid_print
      print('Uncaught error: $error\n$stack');
    }
  });
}

Future<void> _bootBackgroundServices(AppLogger logger) async {
  try {
    sl<SyncEngine>().start();
    await sl<LocalMasterServer>().startIfMaster();
    await sl<LocalMasterDiscovery>().start();
    await LocalRealtimeClient.instance.startIfSlave();
    sl<TerminalConfigRepository>().addListener(() {
      unawaited(sl<LocalMasterServer>().startIfMaster());
      unawaited(LocalRealtimeClient.instance.startIfSlave());
      sl<ThemeCubit>().applyFromConfig();
    });
    logger.info('Background services started', tag: 'boot');
  } catch (error, stack) {
    logger.error(
      'Background boot failed',
      tag: 'boot',
      error: error,
      stackTrace: stack,
    );
  }
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthenticationBloc>(
          create: (_) => sl<AuthenticationBloc>()
            ..add(const AuthenticationSessionRestored()),
        ),
        BlocProvider<TerminalBloc>.value(value: sl<TerminalBloc>()),
        BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
        BlocProvider<SettingsBloc>.value(value: sl<SettingsBloc>()),
        BlocProvider<NetworkBloc>.value(value: sl<NetworkBloc>()),
        BlocProvider<MasterDiscoveryBloc>.value(
          value: sl<MasterDiscoveryBloc>(),
        ),
        BlocProvider<MasterConnectionBloc>.value(
          value: sl<MasterConnectionBloc>(),
        ),
        BlocProvider<MasterPairingBloc>.value(
          value: sl<MasterPairingBloc>(),
        ),
        BlocProvider<DeviceBloc>.value(value: sl<DeviceBloc>()),
        BlocProvider<NotificationBloc>.value(value: sl<NotificationBloc>()),
        BlocProvider<LocalSyncBloc>.value(value: sl<LocalSyncBloc>()),
        BlocProvider<CloudSyncBloc>.value(value: sl<CloudSyncBloc>()),
        BlocProvider<ConflictResolutionBloc>.value(
          value: sl<ConflictResolutionBloc>(),
        ),
        BlocProvider<PrintQueueBloc>.value(value: sl<PrintQueueBloc>()),
        BlocProvider<DashboardBloc>.value(value: sl<DashboardBloc>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'ITARA POS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeState.mode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr'),
              Locale('en'),
              Locale('rn'),
              Locale('sw'),
            ],
            routerConfig: AppRouter.create(),
          );
        },
      ),
    );
  }
}
