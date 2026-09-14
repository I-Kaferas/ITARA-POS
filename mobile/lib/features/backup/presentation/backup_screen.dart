import 'package:flutter/material.dart';

import '../data/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<Map<String, dynamic>> _local = [];
  List<Map<String, dynamic>> _cloud = [];
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    String? cloudError;
    List<Map<String, dynamic>> cloud = [];
    try {
      cloud = await BackupService.instance.cloudBackups();
    } catch (error) {
      cloudError = error.toString().replaceFirst('Exception: ', '');
    }
    final local = await BackupService.instance.localBackups();
    if (!mounted) return;
    setState(() {
      _local = local;
      _cloud = cloud;
      _message = cloudError;
      _loading = false;
    });
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final result = await BackupService.instance.create();
      final cloud = result['cloud'] == true ? 'envoyée au cloud' : 'locale seulement';
      _message = 'Sauvegarde ${result['id']} · $cloud';
      if (result['cloud_error'] != null) _message = '$_message · ${result['cloud_error']}';
      await _reload();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer'),
        content: const Text(
          'La base SQLite, les événements de sync et la configuration de ce terminal seront remplacés. Une copie de secours est gardée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await action();
      _message = 'Restauration terminée.';
      await _reload();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegardes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Android et Windows : base SQLite, fichiers, journaux, événements de sync et configuration. Le cloud reçoit une copie si le terminal est connecté.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.backup_outlined),
                  label: Text(_busy ? 'En cours…' : 'Créer une sauvegarde'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!),
                ],
                const SizedBox(height: 20),
                Text('Sur cet appareil', style: Theme.of(context).textTheme.titleMedium),
                if (_local.isEmpty) const Text('Aucune sauvegarde locale.'),
                for (final row in _local) _tile(row, onRestore: () => _restore(() => BackupService.instance.restoreLocal(row['id'].toString()))),
                const SizedBox(height: 16),
                Text('Cloud', style: Theme.of(context).textTheme.titleMedium),
                if (_cloud.isEmpty) const Text('Aucune copie cloud.'),
                for (final row in _cloud)
                  _tile(row, onRestore: () => _restore(() => BackupService.instance.restoreCloud(row['id'].toString()))),
              ],
            ),
    );
  }

  Widget _tile(Map<String, dynamic> row, {required VoidCallback onRestore}) {
    final platform = row['platform']?.toString() ?? '';
    final events = row['sync_events']?.toString() ?? '0';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(row['created_at']?.toString() ?? row['id']?.toString() ?? ''),
      subtitle: Text('$platform · $events événements de sync'),
      trailing: TextButton(onPressed: _busy ? null : onRestore, child: const Text('Restaurer')),
    );
  }
}
