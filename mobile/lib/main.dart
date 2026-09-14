import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/terminal_config_repository.dart';
import 'data/local/local_database.dart';
import 'features/home/presentation/home_screen.dart';
import 'sync/local_master_discovery.dart';
import 'sync/local_master_server.dart';
import 'sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.ensureInitialized();
  await TerminalConfigRepository.instance.ensureLoaded();
  SyncEngine.instance.start();
  await LocalMasterServer.instance.startIfMaster();
  await LocalMasterDiscovery.instance.start();
  TerminalConfigRepository.instance.addListener(() {
    LocalMasterServer.instance.startIfMaster();
  });
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Mobile',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('rn'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
