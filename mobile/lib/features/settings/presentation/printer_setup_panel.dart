import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/i18n/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../printers/services/printer_manager.dart';
import '../../printers/services/printer_service.dart';
import '../../printers/services/raw_printer_output.dart';

Color get _accent => AppColors.brandInk;
Color get _onAccent =>
    _accent.computeLuminance() > 0.5 ? AppColors.brand900 : Colors.white;

class _Status {
  const _Status(this.ok, this.message);

  final bool ok;
  final String message;
}

/// Setup shown under « Mode d’impression »: printers of this device,
/// network printer (ESC/POS on port 9100) or Bluetooth printer.
class PrinterSetupPanel extends StatefulWidget {
  const PrinterSetupPanel({super.key, required this.config});

  final TerminalConfig config;

  @override
  State<PrinterSetupPanel> createState() => _PrinterSetupPanelState();
}

class _PrinterSetupPanelState extends State<PrinterSetupPanel> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _mac;

  String? _busy;
  _Status? _status;
  List<Printer>? _systemPrinters;
  bool _canListSystem = true;
  List<Map<String, dynamic>>? _found;
  List<BluetoothPrinterDevice>? _devices;

  TerminalConfig get _config => widget.config;
  String get _mode => _config.printerMode;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(
      text: _config.printerMode == 'lan' ? _config.printerHost : '',
    );
    _port = TextEditingController(text: '${_config.printerPort}');
    _mac = TextEditingController(text: _config.bluetoothPrinterAddress);
    if (_mode == 'system') _loadSystemPrinters();
  }

  @override
  void didUpdateWidget(covariant PrinterSetupPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.printerMode != _mode) {
      _status = null;
      if (_mode == 'system' && _systemPrinters == null) _loadSystemPrinters();
    }
    final mac = _config.bluetoothPrinterAddress;
    if (oldWidget.config.bluetoothPrinterAddress != mac && _mac.text != mac) {
      _mac.text = mac;
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _mac.dispose();
    super.dispose();
  }

  Future<void> _save(TerminalConfig Function(TerminalConfig) change) async {
    final repo = TerminalConfigRepository.instance;
    await repo.save(change(repo.config));
    try {
      await PrinterManager.instance.syncDefaultFromConfig();
    } catch (_) {}
  }

  Future<void> _run(String id, Future<_Status?> Function() action) async {
    if (_busy != null) return;
    setState(() {
      _busy = id;
      _status = null;
    });
    _Status? result;
    try {
      result = await action();
    } catch (error) {
      result = _Status(false, _describe(error));
    }
    if (!mounted) return;
    setState(() {
      _busy = null;
      _status = result;
    });
  }

  String _describe(Object error) {
    if (error is StateError) return error.message;
    if (error is SocketException) {
      final reason = error.osError?.message ?? error.message;
      return trf('Imprimante injoignable : {0}', [reason]);
    }
    return error.toString();
  }

  // ── Cet appareil ────────────────────────────────────────────────────────

  Future<void> _loadSystemPrinters() => _run('list', () async {
        final info = await Printing.info();
        if (!info.canListPrinters) {
          _canListSystem = false;
          _systemPrinters = const [];
          return null;
        }
        final printers = await Printing.listPrinters();
        printers.sort((a, b) {
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        _canListSystem = true;
        _systemPrinters = printers;
        return printers.isEmpty
            ? const _Status(false, 'Aucune imprimante installée sur cet appareil.')
            : null;
      });

  Future<void> _pickSystemPrinter(String name) async {
    await _save((c) => c.copyWith(
          printerConnection: 'system',
          printerName: name,
          printerEnabled: true,
        ));
    if (!mounted) return;
    setState(() => _status = _Status(
          true,
          name.isEmpty
              ? 'La fenêtre d’impression s’ouvrira à chaque ticket.'
              : trf('Les tickets partent directement vers « {0} ».', [name]),
        ));
  }

  // ── Réseau ──────────────────────────────────────────────────────────────

  ({String host, int port})? _networkFields() {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 0;
    final validHost = InternetAddress.tryParse(host) != null ||
        RegExp(r'^[A-Za-z0-9]([A-Za-z0-9\-\.]*[A-Za-z0-9])?$').hasMatch(host);
    if (host.isEmpty || !validHost) {
      setState(() => _status = const _Status(false, 'Saisissez une adresse IP valide, ex. 192.168.1.50'));
      return null;
    }
    if (port <= 0 || port > 65535) {
      setState(() => _status = const _Status(false, 'Port invalide (9100 pour la plupart des imprimantes).'));
      return null;
    }
    return (host: host, port: port);
  }

  Future<bool> _saveNetwork() async {
    final fields = _networkFields();
    if (fields == null) return false;
    await _save((c) => c.copyWith(
          printerConnection: 'lan',
          printerHost: fields.host,
          printerPort: fields.port,
          printerEnabled: true,
        ));
    return true;
  }

  Future<void> _scanNetwork() => _run('scan', () async {
        final found = await PrinterService.instance.discoverNetworkPrinters();
        _found = found;
        return found.isEmpty
            ? const _Status(
                false,
                'Aucune imprimante trouvée sur le port 9100. Vérifiez qu’elle est allumée et sur le même réseau, ou saisissez son IP.',
              )
            : _Status(true, trf('{0} imprimante(s) trouvée(s). Touchez-en une pour l’utiliser.', [found.length]));
      });

  Future<void> _testNetwork() async {
    final fields = _networkFields();
    if (fields == null) return;
    await _run('test', () async {
      final ms = await RawPrinterOutput.instance.probeNetwork(fields.host, fields.port);
      return _Status(true, trf('Imprimante joignable sur {0} ({1} ms).', ['${fields.host}:${fields.port}', ms]));
    });
  }

  // ── Bluetooth ───────────────────────────────────────────────────────────

  Future<void> _scanBluetooth() => _run('scan', () async {
        final devices = await RawPrinterOutput.instance.bluetoothDevices();
        _devices = devices;
        if (devices.isEmpty) {
          return _Status(
            false,
            Platform.isWindows
                ? 'Aucun appareil détecté. Allumez l’imprimante près de ce PC puis relancez la recherche.'
                : 'Aucun appareil appairé. Appairez l’imprimante dans les paramètres Bluetooth puis relancez.',
          );
        }
        return _Status(true, trf('{0} appareil(s). Touchez votre imprimante pour l’utiliser.', [devices.length]));
      });

  Future<void> _pickBluetooth(String address, String name) async {
    await _save((c) => c.copyWith(
          printerConnection: 'bluetooth',
          printerBluetoothAddress: RawPrinterOutput.normalizeMac(address),
          printerBluetoothName: name,
          printerEnabled: true,
        ));
    if (!mounted) return;
    setState(() => _status = _Status(true, trf('Imprimante « {0} » sélectionnée.', [name])));
  }

  Future<void> _useManualMac() async {
    final mac = _mac.text.trim();
    if (!RawPrinterOutput.isValidMac(mac)) {
      setState(() => _status = const _Status(false, 'Adresse MAC invalide, format attendu 66:02:BD:06:18:7B'));
      return;
    }
    await _pickBluetooth(mac, _config.printerBluetoothName.isEmpty ? 'Imprimante Bluetooth' : _config.printerBluetoothName);
  }

  Future<void> _testBluetooth() async {
    final address = _config.bluetoothPrinterAddress;
    if (address.isEmpty) {
      setState(() => _status = const _Status(false, 'Choisissez d’abord une imprimante Bluetooth.'));
      return;
    }
    await _run('test', () async {
      await RawPrinterOutput.instance.probeBluetooth(address);
      final name = _config.printerBluetoothName.isEmpty ? address : _config.printerBluetoothName;
      return _Status(true, trf('Connecté à {0}.', [name]));
    });
  }

  // ── Test ticket ─────────────────────────────────────────────────────────

  Future<void> _printTest() async {
    if (_mode == 'lan' && !await _saveNetwork()) return;
    if (_mode == 'bluetooth' && _config.bluetoothPrinterAddress.isEmpty) {
      setState(() => _status = const _Status(false, 'Choisissez d’abord une imprimante Bluetooth.'));
      return;
    }
    await _run('print', () async {
      final config = TerminalConfigRepository.instance.config;
      final width = config.printerPaperWidthMm;
      switch (config.printerMode) {
        case 'lan':
          final target = RawPrinterTarget.network(config.printerHost, port: config.printerPort);
          await RawPrinterOutput.instance.printPdf(
            await _testPdf(config, 'Réseau', target.label),
            target,
            paperWidthMm: width,
          );
          return _Status(true, trf('Ticket de test envoyé à {0}.', [target.label]));
        case 'bluetooth':
          final target = RawPrinterTarget.bluetooth(config.bluetoothPrinterAddress);
          final name = config.printerBluetoothName.isEmpty ? target.label : config.printerBluetoothName;
          await RawPrinterOutput.instance.printPdf(
            await _testPdf(config, 'Bluetooth', name),
            target,
            paperWidthMm: width,
          );
          return _Status(true, trf('Ticket de test envoyé à {0}.', [name]));
        default:
          final wanted = config.printerName.trim();
          final pdf = await _testPdf(config, 'Cet appareil', wanted.isEmpty ? 'Fenêtre d’impression' : wanted);
          final match = (_systemPrinters ?? const <Printer>[])
              .where((item) => item.name == wanted)
              .firstOrNull;
          if (match != null) {
            final done = await Printing.directPrintPdf(
              printer: match,
              onLayout: (_) async => pdf,
              name: 'test-impression',
            );
            return done
                ? _Status(true, trf('Ticket de test envoyé à {0}.', ['« $wanted »']))
                : _Status(false, trf('« {0} » a refusé le document.', [wanted]));
          }
          await Printing.layoutPdf(onLayout: (_) async => pdf, name: 'test-impression');
          return null;
      }
    });
  }

  Future<Uint8List> _testPdf(TerminalConfig config, String mode, String target) async {
    final width = config.printerPaperWidthMm;
    final format = width > 80
        ? PdfPageFormat.a4
        : PdfPageFormat(
            width * PdfPageFormat.mm,
            double.infinity,
            marginAll: 3 * PdfPageFormat.mm,
          );
    final small = width <= 58;
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final rows = [
      ('Mode', mode),
      ('Imprimante', target),
      ('Papier', width > 80 ? 'A4' : '$width mm'),
      if (config.deviceName.isNotEmpty) ('Appareil', config.deviceName),
      ('Date', '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}'),
    ];
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: format,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            config.brandName.isEmpty ? 'ITARA POS' : config.brandName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: small ? 12 : 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text('Test d\'impression', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(thickness: 0.8),
          for (final (label, value) in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: small ? 52 : 68, child: pw.Text(label, style: const pw.TextStyle(fontSize: 8.5))),
                  pw.Expanded(
                    child: pw.Text(value, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            ),
          pw.Divider(thickness: 0.8),
          pw.Text('ABCDEFGHIJKLMNOPQRSTUVWXYZ', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
          pw.Text('0123456789  é è à ç ù', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            color: PdfColors.black,
            child: pw.Text(
              'IMPRIMANTE PRÊTE',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    ));
    return doc.save();
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EnableRow(
          enabled: _config.printerEnabled,
          onChanged: (value) => _save((c) => c.copyWith(printerEnabled: value)),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_mode),
            child: switch (_mode) {
              'lan' => _buildNetwork(),
              'bluetooth' => _buildBluetooth(),
              _ => _buildSystem(),
            },
          ),
        ),
        if (_status != null) ...[
          const SizedBox(height: 12),
          _StatusBanner(status: _status!),
        ],
      ],
    );
  }

  Widget _buildSystem() {
    final printers = _systemPrinters;
    final selected = _config.printerName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Imprimantes de cet appareil',
          trailing: _canListSystem
              ? _IconAction(
                  icon: Icons.refresh,
                  tooltip: 'Actualiser',
                  busy: _busy == 'list',
                  onTap: _loadSystemPrinters,
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (!_canListSystem)
          const _Hint(
            icon: Icons.info_outline,
            text:
                'Ce système ne donne pas accès à la liste des imprimantes : la fenêtre d’impression s’ouvre à chaque ticket (Mopria, service du fabricant…). Pour l’imprimante intégrée d’un terminal Sunmi, choisissez Bluetooth : elle s’affiche sous le nom « InnerPrinter ».',
          )
        else if (printers == null)
          const _Loading(label: 'Recherche des imprimantes installées…')
        else ...[
          _OptionTile(
            icon: Icons.open_in_new,
            title: 'Choisir à chaque impression',
            subtitle: 'La fenêtre d’impression du système s’ouvre',
            selected: selected.isEmpty,
            onTap: () => _pickSystemPrinter(''),
          ),
          for (final printer in printers)
            _OptionTile(
              icon: Icons.print_outlined,
              title: printer.name,
              subtitle: [
                if (printer.isDefault) tr('Par défaut'),
                if ((printer.model ?? '').isNotEmpty) printer.model!,
                if ((printer.location ?? '').isNotEmpty) printer.location!,
                if (!printer.isAvailable) tr('Indisponible'),
              ].join(' · '),
              selected: printer.name == selected,
              onTap: () => _pickSystemPrinter(printer.name),
            ),
          if (selected.isNotEmpty && !printers.any((p) => p.name == selected))
            _Hint(
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              text: trf('« {0} » n’est plus installée : la fenêtre d’impression s’ouvrira.', [selected]),
            ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionButton(
              icon: Icons.receipt_long_outlined,
              label: 'Imprimer un test',
              primary: true,
              busy: _busy == 'print',
              onTap: _printTest,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNetwork() {
    final found = _found;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Imprimante réseau (Ethernet / Wi-Fi)'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _Field(
                controller: _host,
                label: 'Adresse IP',
                hint: '192.168.1.50',
                icon: Icons.lan_outlined,
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 104,
              child: _Field(
                controller: _port,
                label: 'Port',
                hint: '9100',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionButton(
              icon: Icons.save_outlined,
              label: 'Enregistrer',
              primary: true,
              busy: _busy == 'save',
              onTap: () => _run('save', () async {
                final ok = await _saveNetwork();
                final target = '${_host.text.trim()}:${_port.text.trim()}';
                return ok ? _Status(true, trf('Imprimante réseau {0} enregistrée.', [target])) : _status;
              }),
            ),
            _ActionButton(
              icon: Icons.radar,
              label: 'Rechercher sur le réseau',
              busy: _busy == 'scan',
              onTap: _scanNetwork,
            ),
            _ActionButton(
              icon: Icons.network_check,
              label: 'Tester la connexion',
              busy: _busy == 'test',
              onTap: _testNetwork,
            ),
            _ActionButton(
              icon: Icons.receipt_long_outlined,
              label: 'Imprimer un test',
              busy: _busy == 'print',
              onTap: _printTest,
            ),
          ],
        ),
        if (_busy == 'scan') ...[
          const SizedBox(height: 10),
          const _Loading(label: 'Analyse du réseau local (port 9100)…'),
        ] else if (found != null && found.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final item in found)
            _OptionTile(
              icon: Icons.print_outlined,
              title: item['host'].toString(),
              subtitle: 'ESC/POS · port ${item['port']}',
              selected: _config.printerMode == 'lan' &&
                  _config.printerHost == item['host'].toString() &&
                  _config.printerPort == item['port'],
              onTap: () {
                _host.text = item['host'].toString();
                _port.text = '${item['port']}';
                _run('save', () async {
                  await _saveNetwork();
                  return _Status(true, trf('Imprimante « {0} » sélectionnée.', [item['host']]));
                });
              },
            ),
        ],
        const SizedBox(height: 12),
        const _Hint(
          icon: Icons.lightbulb_outline,
          text:
              'Compatible avec toute imprimante ticket ESC/POS en Ethernet ou Wi-Fi (Epson, Star, Xprinter, Rongta, Bixolon…) sur le port 9100 ; une imprimante A4 réseau reçoit le PDF sur ce même port. Réservez une IP fixe à l’imprimante dans votre routeur pour que tous les appareils la joignent toujours à la même adresse.',
        ),
      ],
    );
  }

  Widget _buildBluetooth() {
    final service = RawPrinterOutput.instance;
    final devices = _devices;
    final address = _config.bluetoothPrinterAddress;
    final name = _config.printerBluetoothName;
    if (!service.bluetoothSupported) {
      return const _Hint(
        icon: Icons.bluetooth_disabled,
        text: 'Le Bluetooth n’est pas pris en charge sur cette plateforme. Utilisez le mode Réseau ou Cet appareil.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Imprimante Bluetooth'),
        const SizedBox(height: 8),
        if (address.isNotEmpty)
          _OptionTile(
            icon: Icons.bluetooth_connected,
            title: name.isEmpty ? 'Imprimante Bluetooth' : name,
            subtitle: address,
            selected: true,
            onTap: null,
          )
        else
          const _Hint(
            icon: Icons.bluetooth_searching,
            text: 'Aucune imprimante sélectionnée. Lancez une recherche puis touchez votre imprimante.',
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionButton(
              icon: Icons.bluetooth_searching,
              label: Platform.isWindows ? 'Rechercher (5 s)' : 'Imprimantes appairées',
              primary: address.isEmpty,
              busy: _busy == 'scan',
              onTap: _scanBluetooth,
            ),
            _ActionButton(
              icon: Icons.link,
              label: 'Tester la connexion',
              busy: _busy == 'test',
              onTap: _testBluetooth,
            ),
            _ActionButton(
              icon: Icons.receipt_long_outlined,
              label: 'Imprimer un test',
              primary: address.isNotEmpty,
              busy: _busy == 'print',
              onTap: _printTest,
            ),
          ],
        ),
        if (_busy == 'scan') ...[
          const SizedBox(height: 10),
          _Loading(
            label: Platform.isWindows
                ? 'Recherche des imprimantes Bluetooth à proximité…'
                : 'Lecture des appareils appairés…',
          ),
        ] else if (devices != null && devices.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final device in devices)
            _OptionTile(
              icon: _looksLikePrinter(device.name) ? Icons.print_outlined : Icons.bluetooth,
              title: device.name,
              subtitle: device.address,
              selected: device.address == address,
              onTap: () => _pickBluetooth(device.address, device.name),
            ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _Field(
                controller: _mac,
                label: 'Adresse MAC (saisie manuelle)',
                hint: '66:02:BD:06:18:7B',
                icon: Icons.bluetooth,
              ),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.check,
              label: 'Utiliser',
              busy: false,
              onTap: _useManualMac,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Hint(
          icon: Icons.lightbulb_outline,
          text: Platform.isWindows
              ? 'Allumez l’imprimante près du PC : la recherche détecte les imprimantes Bluetooth basse consommation (BLE). Une imprimante Bluetooth classique installée dans Windows apparaît sous « Cet appareil ».'
              : 'Appairez d’abord l’imprimante dans Paramètres › Bluetooth (code souvent 0000 ou 1234). Les tickets sont envoyés en ESC/POS, compatible avec les imprimantes 58 et 80 mm. Sur un terminal Sunmi, l’imprimante intégrée s’appelle « InnerPrinter ».',
        ),
      ],
    );
  }

  bool _looksLikePrinter(String name) {
    final value = name.toLowerCase();
    return const ['print', 'pos', 'mpt', 'rpp', 'xp-', 'pt-', 'innerprinter', 'thermal', 'tm-']
        .any(value.contains);
  }
}

class _EnableRow extends StatelessWidget {
  const _EnableRow({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.print : Icons.print_disabled_outlined,
            size: 20,
            color: enabled ? _accent : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Impression des tickets'),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  tr(enabled
                      ? 'Les tickets partent vers l’imprimante configurée ci-dessous.'
                      : 'Désactivée : les tickets s’ouvrent dans la fenêtre d’impression.'),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            tr(title),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? _accent.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? _accent : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? _accent : AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          tr(subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: selected ? _accent : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? _onAccent : AppColors.textPrimary;
    final leading = busy
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Icon(icon, size: 16, color: fg);
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.ibmPlexSans(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
    if (primary) {
      return FilledButton.icon(
        onPressed: busy ? null : onTap,
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(_accent),
          foregroundColor: WidgetStatePropertyAll(_onAccent),
        ),
        icon: leading,
        label: Text(tr(label)),
      );
    }
    return OutlinedButton.icon(
      onPressed: busy ? null : onTap,
      style: style.copyWith(
        foregroundColor: WidgetStatePropertyAll(AppColors.textPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
      ),
      icon: leading,
      label: Text(tr(label)),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr(tooltip),
      visualDensity: VisualDensity.compact,
      onPressed: busy ? null : onTap,
      icon: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            )
          : Icon(icon, size: 18, color: _accent),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.ibmPlexSans(fontSize: 13.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        labelText: tr(label),
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        filled: true,
        fillColor: AppColors.fieldFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.info;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(text),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(label),
              style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final _Status status;

  @override
  Widget build(BuildContext context) {
    final color = status.ok ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: status.ok ? AppColors.successBg : AppColors.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status.ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(status.message),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
