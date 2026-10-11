import '../api/api_client.dart';
import 'terminal_config_repository.dart';

class TerminalStoreOption {
  const TerminalStoreOption({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  String get label => code.trim().isEmpty ? name : '$name · ${code.trim()}';
}

Future<List<TerminalStoreOption>> loadTerminalStores() async {
  final body = await ApiClient().get('/stores');
  final data = body['data'];
  if (data is! List) return const [];

  final stores = <TerminalStoreOption>[];
  for (final raw in data) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    if (item['is_active'] == false) continue;
    final id = item['id']?.toString().trim() ?? '';
    final name = item['name']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty) continue;
    stores.add(TerminalStoreOption(
      id: id,
      name: name,
      code: item['code']?.toString() ?? '',
    ));
  }
  return stores;
}

Future<void> selectTerminalStore(TerminalStoreOption store) async {
  final repo = TerminalConfigRepository.instance;
  if (repo.config.storeId == store.id) return;
  await repo.save(repo.config.copyWith(storeId: store.id));
}
