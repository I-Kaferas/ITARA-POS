import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/terminal_config_repository.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/local/local_database.dart';
import 'sync/local_master_discovery.dart';
import 'sync/local_master_server.dart';
import 'sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.ensureInitialized();
  await TerminalConfigRepository.instance.ensureLoaded();
  await ThemeController.instance.load();
  runApp(const PosApp());
  // Defer background services so the first frame paints quickly.
  unawaited(_bootBackgroundServices());
}

Future<void> _bootBackgroundServices() async {
  SyncEngine.instance.start();
  await LocalMasterServer.instance.startIfMaster();
  await LocalMasterDiscovery.instance.start();
  TerminalConfigRepository.instance.addListener(() {
    unawaited(LocalMasterServer.instance.startIfMaster());
    ThemeController.instance.applyFromConfig();
  });
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'ITARA POS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.mode,
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
    );
  }
}
