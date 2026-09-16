import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_error_view.dart';
import '../data/pos_api_service.dart';
import '../domain/pos_models.dart';
import 'widgets/pos_ui.dart';

class PosReservationsScreen extends StatefulWidget {
  const PosReservationsScreen({super.key});

  @override
  State<PosReservationsScreen> createState() => _PosReservationsScreenState();
}

class _PosReservationsScreenState extends State<PosReservationsScreen> {
  final _api = PosApiService();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static const _statuses = [
    'pending',
    'confirmed',
    'seated',
    'completed',
    'cancelled',
    'no_show',
  ];

  List<PosReservation> _items = [];
  bool _loading = true;
  String? _error;
  String? _statusSavingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.fetchReservations();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending' => 'En attente',
      'confirmed' => 'Confirmée',
      'seated' => 'Installée',
      'completed' => 'Terminée',
      'cancelled' => 'Annulée',
      'no_show' => 'No-show',
      _ => status,
    };
  }

  PosBadgeTone _statusTone(String status) {
    return switch (status) {
      'confirmed' || 'seated' => PosBadgeTone.brand,
      'completed' => PosBadgeTone.success,
      'cancelled' => PosBadgeTone.neutral,
      'no_show' => PosBadgeTone.danger,
      _ => PosBadgeTone.warning,
    };
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setStatus(PosReservation item, String status) async {
    if (item.status == status) return;
    setState(() => _statusSavingId = item.id);
    try {
      final updated = await _api.setReservationStatus(item.id, status);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final row in _items)
            if (row.id == item.id) updated else row,
        ];
      });
    } catch (error) {
      _snack(error.toString().replaceFirst('Exception: ', ''));
      await _load();
    } finally {
      if (mounted) setState(() => _statusSavingId = null);
    }
  }

  Future<void> _openForm({PosReservation? existing}) async {
    final guestCtrl = TextEditingController(text: existing?.guestName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final partyCtrl = TextEditingController(text: '${existing?.partySize ?? 2}');
    var reservedAt = existing?.reservedAtDateTime ?? _defaultReservedAt();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusXl)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null ? 'Nouvelle réservation' : 'Modifier la réservation',
                        style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: guestCtrl,
                        decoration: _fieldDecoration(label: 'Nom du client'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: partyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _fieldDecoration(label: 'Nombre de couverts'),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: reservedAt,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(reservedAt),
                          );
                          if (time == null) return;
                          setLocal(() {
                            reservedAt = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(PosUi.radiusMd),
                        child: InputDecorator(
                          decoration: _fieldDecoration(label: 'Date et heure'),
                          child: Text(_dateFormat.format(reservedAt)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _fieldDecoration(label: 'Téléphone'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: _fieldDecoration(label: 'Notes'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving ? null : () => Navigator.pop(context),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final guest = guestCtrl.text.trim();
                                      final party = int.tryParse(partyCtrl.text.trim()) ?? 0;
                                      if (guest.isEmpty || party < 1) {
                                        _snack('Nom et nombre de couverts requis');
                                        return;
                                      }
                                      setLocal(() => saving = true);
                                      final payload = {
                                        'guest_name': guest,
                                        'party_size': party,
                                        'reserved_at': reservedAt.toUtc().toIso8601String(),
                                        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                        'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                        if (existing != null) 'status': existing.status,
                                      };
                                      try {
                                        if (existing == null) {
                                          await _api.createReservation(payload);
                                        } else {
                                          await _api.updateReservation(existing.id, payload);
                                        }
                                        if (context.mounted) Navigator.pop(context);
                                        await _load();
                                      } catch (error) {
                                        setLocal(() => saving = false);
                                        _snack(error.toString().replaceFirst('Exception: ', ''));
                                      }
                                    },
                              style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
                              child: Text(existing == null ? 'Créer' : 'Enregistrer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    guestCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
    partyCtrl.dispose();
  }

  DateTime _defaultReservedAt() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Réservations', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.brand600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: RefreshIndicator(
        color: AppColors.brand500,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          LoadingView(message: 'Chargement des réservations…'),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: ErrorView(message: _error!, onRetry: _load),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: EmptyState(
              icon: Icons.event_seat_outlined,
              title: 'Aucune réservation',
              subtitle: 'Créez une réservation pour préparer l’accueil.',
              action: FilledButton(
                onPressed: () => _openForm(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.brand600),
                child: const Text('Nouvelle réservation'),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: PosUi.pagePadding(context).copyWith(bottom: 88),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final reserved = item.reservedAtDateTime;
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(PosUi.radiusXl),
          child: InkWell(
            borderRadius: BorderRadius.circular(PosUi.radiusXl),
            onTap: () => _openForm(existing: item),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PosUi.radiusXl),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.guestName,
                          style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      PosBadge(label: _statusLabel(item.status), tone: _statusTone(item.status)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      '${item.partySize} couverts',
                      if (reserved != null) _dateFormat.format(reserved),
                      if ((item.phone ?? '').isNotEmpty) item.phone!,
                      if (item.reference.isNotEmpty) item.reference,
                    ].join(' · '),
                    style: PosUi.caption(),
                  ),
                  if ((item.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.notes!, style: PosUi.body(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final status in _statuses)
                        ChoiceChip(
                          label: Text(_statusLabel(status), style: const TextStyle(fontSize: 11)),
                          selected: item.status == status,
                          onSelected: _statusSavingId == item.id
                              ? null
                              : (_) => _setStatus(item, status),
                          selectedColor: AppColors.brand100,
                          labelStyle: TextStyle(
                            color: item.status == status ? AppColors.brandInk : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: item.status == status ? AppColors.brand200 : AppColors.border,
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

InputDecoration _fieldDecoration({required String label}) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.fieldFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PosUi.radiusMd),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PosUi.radiusMd),
      borderSide: BorderSide(color: AppColors.border),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

extension on PosReservation {
  DateTime? get reservedAtDateTime => DateTime.tryParse(reservedAt);
}
