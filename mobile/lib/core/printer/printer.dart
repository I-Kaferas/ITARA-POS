library;

/// Printer engine (Clean Architecture — core/printer).
///
/// Feature UI / BLoCs live under [features/printers]; the engine itself is core.
export '../../features/printers/data/data.dart';
export '../../features/printers/domain/domain.dart';
export '../../sync/master_print_client.dart';
export '../../sync/master_print_server.dart';
export '../../sync/print_spooler.dart';
