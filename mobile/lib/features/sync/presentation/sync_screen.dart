import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/network/network_bloc.dart';
import '../../../core/network/operating_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../sync/offline_store.dart';
import '../../../sync/sync_engine.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<Map<String, dynamic>> _items = [];
  Map<String, int> _ledger = const {};
  Map<String, dynamic>? _latestChain;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SyncEngine.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    SyncEngine.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final store = OfflineStore.instance;
    final items = await store.queueDetails();
    final ledger = await store.localLedgerCounts();
    final latest = await store.latestSaleChain();
    if (!mounted) return;
    setState(() {
      _items = items;
      _ledger = ledger;
      _latestChain = latest;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    await SyncEngine.instance.syncNow();
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final engine = SyncEngine.instance;
    final snapshot = engine.snapshot;

    return ColoredBox(
      color: AppColors.canvas,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          BlocBuilder<NetworkBloc, NetworkState>(
            builder: (context, network) => _OperatingModeCard(state: network),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Stat(label: 'En attente', value: '${snapshot.pending}', color: AppColors.accent),
              _Stat(label: 'Synchronisées', value: '${snapshot.synced}', color: AppColors.success),
              _Stat(label: 'Échecs', value: '${snapshot.failed}', color: AppColors.danger),
              _Stat(label: 'Conflits', value: '${snapshot.conflicts}', color: AppColors.brand700),
            ],
          ),
          const SizedBox(height: 16),
          _ChainCard(ledger: _ledger, latest: _latestChain),
          const SizedBox(height: 16),
          Text(
            snapshot.modeLabel,
            style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Chemin: ${snapshot.mode.syncPath}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            'Cible: ${snapshot.target ?? 'file locale (SQLite)'}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            'Dernière sync: ${snapshot.lastSyncAt == null ? '—' : DateFormat('dd/MM HH:mm').format(snapshot.lastSyncAt!)}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.mode == OperatingMode.isolatedOffline
                ? 'Slave → Sync Queue → Master → Cloud (au retour)'
                : 'File → API → serveur → ACK → marqué synchronisé',
            style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
          ),
          Text(
            engine.lastSent == 0 && engine.lastAcknowledged == 0
                ? (snapshot.mode == OperatingMode.isolatedOffline
                    ? 'Mode C — opérations en file locale. Rien n'est perdu.'
                    : snapshot.mode == OperatingMode.localOffline
                        ? 'Mode B — commerce local. Sync cloud en attente du réseau.'
                        : 'En attente du retour réseau. Rien n'est supprimé avant l'ACK.')
                : 'Dernier passage : ${engine.lastSent} envoyés · ${engine.lastAcknowledged} ACK · ${engine.lastKept} conservés · 0 perdu',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (engine.lastReport.message.isNotEmpty || engine.lastReport.hasDetails) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dernière synchronisation',
                    style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700),
                  ),
                  if (engine.lastReport.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(engine.lastReport.message, style: TextStyle(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 8),
                  ...engine.lastReport.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(line.label)),
                          Text('${line.count}', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (snapshot.lastError != null) ...[
            const SizedBox(height: 8),
            Text(snapshot.lastError!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _syncNow,
                icon: const Icon(Icons.sync),
                label: Text(_busy ? 'Synchronisation…' : 'Synchroniser maintenant'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await OfflineStore.instance.retryAllFailed();
                  await SyncEngine.instance.syncNow();
                  await _reload();
                },
                child: const Text('Relancer les échecs'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('File d'attente', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Text('Aucune transaction locale.', style: TextStyle(color: AppColors.textMuted))
          else
            ..._items.map((item) {
              final status = item['status'] as String? ?? '';
              return Card(
                child: ListTile(
                  title: Text('${item['entity_type']} · ${item['entity_id']}'),
                  subtitle: Text(
                    'Statut: $status · essais: ${item['attempts'] ?? 0}'
                    '${item['error_message'] == null ? '' : '\n${item['error_message']}'}',
                  ),
                  trailing: status == 'synced'
                      ? null
                      : IconButton(
                          tooltip: 'Relancer',
                          onPressed: () async {
                            await OfflineStore.instance.retryNow(item['id'] as String);
                            await SyncEngine.instance.syncNow();
                            await _reload();
                          },
                          icon: const Icon(Icons.refresh),
                        ),
                ),
              );
            }),
        ],
          ),
        ),
      ),
    );
  }
}

class _OperatingModeCard extends StatelessWidget {
  const _OperatingModeCard({required this.state});

  final NetworkState state;

  @override
  Widget build(BuildContext context) {
    final mode = state.mode;
    final color = switch (mode) {
      OperatingMode.fullOnline => AppColors.success,
      OperatingMode.localOffline => AppColors.accent,
      OperatingMode.isolatedOffline => AppColors.warning,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                mode.label,
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mode.description,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            state.status.wire,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rôle ${state.role.label} · Master ${state.masterReachable ? 'OK' : '—'} · Cloud ${state.internetReachable ? 'OK' : '—'}',
            style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Chemin: ${mode.syncPath}',
            style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CapChip('CanSell', state.canSell),
              _CapChip('CanSyncMaster', state.canSyncMaster),
              _CapChip('CanSyncCloud', state.canSyncCloud),
              _CapChip('CanPrint', state.canPrint),
              _CapChip('CanUseKitchen', state.canUseKitchen),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapChip extends StatelessWidget {
  const _CapChip(this.label, this.enabled);

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label ${enabled ? '✓' : '—'}',
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ChainCard extends StatelessWidget {
  const _ChainCard({required this.ledger, required this.latest});

  final Map<String, int> ledger;
  final Map<String, dynamic>? latest;

  @override
  Widget build(BuildContext context) {
    final chain = latest;
    final status = chain?['sync_status']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chaîne locale — fonctionne sans internet',
            style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Vente → paiement → mouvement de stock → événement de sync. Enregistré dans SQLite sur Android et Windows.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip('Ventes', ledger['sales'] ?? 0),
              _Chip('Paiements', ledger['payments'] ?? 0),
              _Chip('Stock', ledger['stock_movements'] ?? 0),
              _Chip('Sync', ledger['sync_events'] ?? 0),
            ],
          ),
          if (chain != null) ...[
            const SizedBox(height: 10),
            Text(
              '${chain['reference']} · paiement ${chain['payments']} · stock ${chain['movements']} · sync ${chain['events']}'
              '${status == null || status.isEmpty ? '' : ' · $status'}',
              style: GoogleFonts.ibmPlexMono(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label $value', style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

