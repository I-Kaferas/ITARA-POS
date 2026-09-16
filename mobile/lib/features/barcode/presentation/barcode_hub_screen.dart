import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide BarcodeType;

import '../../../core/theme/app_colors.dart';
import '../data/barcode_api_service.dart';
import '../domain/barcode_models.dart';
import '../services/barcode_print_service.dart';
import '../services/hid_scanner_controller.dart';
import 'camera_scan_screen.dart';
import 'widgets/barcode_label_preview.dart';
import 'widgets/hid_scanner_field.dart';

class BarcodeHubScreen extends StatefulWidget {
  const BarcodeHubScreen({super.key});

  @override
  State<BarcodeHubScreen> createState() => _BarcodeHubScreenState();
}

class _BarcodeHubScreenState extends State<BarcodeHubScreen> {
  final _api = BarcodeApiService();
  final _printService = BarcodePrintService();
  late final HidScannerController _hidScanner;

  final _searchController = TextEditingController();
  final _assignProductIdController = TextEditingController();

  String? _lastScan;
  BarcodeLookupResult? _lookup;
  List<BarcodeRecord> _searchResults = [];
  BarcodeRecord? _generated;
  PosBarcodeType _generateType = PosBarcodeType.internal;
  PosBarcodeType _assignType = PosBarcodeType.internal;
  bool _loading = false;
  String? _error;
  String _scannerMode = 'hid';

  @override
  void initState() {
    super.initState();
    _hidScanner = HidScannerController(onScan: _onHidScan);
  }

  @override
  void dispose() {
    _hidScanner.dispose();
    _searchController.dispose();
    _assignProductIdController.dispose();
    super.dispose();
  }

  Future<void> _onHidScan(String code) async {
    setState(() => _lastScan = code);
    await _lookupCode(code);
  }

  Future<void> _onCameraScan(String code, BarcodeFormat format) async {
    setState(() {
      _lastScan = code;
      _scannerMode = 'camera';
    });
    await _lookupCode(code);
  }

  Future<void> _lookupCode(String code) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.lookup(code);
      setState(() {
        _lookup = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _api.search(query);
      setState(() {
        _searchResults = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final generated = await _api.generate(_generateType);
      setState(() {
        _generated = generated;
        _lastScan = generated.barcode;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _assign() async {
    final productId = _assignProductIdController.text.trim();
    final barcode = _generated?.barcode ?? _lastScan;
    if (productId.isEmpty || barcode == null || barcode.isEmpty) {
      setState(() => _error = 'Product ID and barcode are required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final assigned = await _api.assignToProduct(
        productId: productId,
        barcode: barcode,
        type: _generated?.type ?? _assignType,
        isPrimary: true,
      );
      setState(() {
        _generated = assigned;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code-barres assigné au produit.')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _printCurrent() async {
    final barcode = _generated?.barcode ?? _lookup?.barcode?.barcode ?? _lastScan;
    if (barcode == null) return;

    final type = _generated?.type ?? _lookup?.barcode?.type ?? PosBarcodeType.internal;
    final label = _lookup?.productName ?? 'POS Label';

    await _printService.printLabel(
      BarcodePrintPayload(
        barcode: barcode,
        type: type,
        label: label,
        typeLabel: type.label,
        isPrimary: true,
      ),
    );
  }

  void _openCameraScanner() {
    final cameraSupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (!cameraSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La caméra n’est disponible que sur mobile. Utilisez le scanner USB / Bluetooth.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CameraScanScreen(onScan: _onCameraScan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewBarcode = _generated?.barcode ?? _lookup?.barcode?.barcode ?? _lastScan;
    final previewType = _generated?.type ?? _lookup?.barcode?.type ?? PosBarcodeType.internal;
    final previewLabel = _lookup?.productName ?? _generated?.productName;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Codes-barres')),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _sectionTitle('Scan'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'hid', label: Text('USB / BT HID'), icon: Icon(Icons.usb)),
                  ButtonSegment(value: 'camera', label: Text('Caméra'), icon: Icon(Icons.camera_alt)),
                ],
                selected: {_scannerMode},
                onSelectionChanged: (value) {
                  setState(() => _scannerMode = value.first);
                  if (value.first == 'camera') {
                    _openCameraScanner();
                  } else {
                    _hidScanner.focusNode.requestFocus();
                  }
                },
              ),
              const SizedBox(height: 8),
              if (_scannerMode == 'hid')
                Text(
                  'Scanner USB ou Bluetooth (mode clavier) actif — scannez un code.',
                  style: GoogleFonts.ibmPlexSans(color: AppColors.textSecondary, fontSize: 13),
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _openCameraScanner,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Ouvrir la caméra'),
                ),
              ),
              if (_lastScan != null) ...[
                const SizedBox(height: 8),
                Text('Dernier scan : $_lastScan', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              _sectionTitle('Recherche'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Rechercher un code',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _search, icon: const Icon(Icons.search)),
                ],
              ),
              if (_searchResults.isNotEmpty)
                ..._searchResults.map(
                  (item) => ListTile(
                    title: Text(item.barcode),
                    subtitle: Text('${item.type.label}${item.productName != null ? ' · ${item.productName}' : ''}'),
                    onTap: () => _lookupCode(item.barcode),
                  ),
                ),
              const SizedBox(height: 16),
              _sectionTitle('Générer'),
              DropdownButtonFormField<PosBarcodeType>(
                initialValue: _generateType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: PosBarcodeType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _generateType = value);
                },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Générer un code'),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Assigner'),
              TextField(
                controller: _assignProductIdController,
                decoration: const InputDecoration(
                  labelText: 'ID produit (UUID)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PosBarcodeType>(
                initialValue: _assignType,
                decoration: const InputDecoration(
                  labelText: 'Type (si scan manuel)',
                  border: OutlineInputBorder(),
                ),
                items: PosBarcodeType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _assignType = value);
                },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _assign,
                icon: const Icon(Icons.link),
                label: const Text('Assigner au produit'),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Aperçu & impression'),
              if (previewBarcode != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BarcodeLabelPreview(
                      barcode: previewBarcode,
                      type: previewType,
                      label: previewLabel,
                    ),
                  ),
                ),
              if (_lookup != null && _lookup!.found) ...[
                const SizedBox(height: 8),
                Text('Produit : ${_lookup!.productName ?? '—'}'),
                Text('SKU : ${_lookup!.productSku ?? '—'}'),
                if (_lookup!.variantSku != null) Text('Variante : ${_lookup!.variantSku}'),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: previewBarcode == null ? null : _printCurrent,
                icon: const Icon(Icons.print),
                label: const Text('Imprimer l\'étiquette'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
              ),
            ),
          ),
          if (_loading)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_scannerMode == 'hid') HidScannerField(controller: _hidScanner),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.brand900),
      ),
    );
  }
}
