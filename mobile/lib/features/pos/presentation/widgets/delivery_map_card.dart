import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

import 'pos_ui.dart';

/// Default center — Bujumbura (common ITARA POS locale). GPS overrides when available.
const LatLng kDefaultDeliveryCenter = LatLng(-3.3822, 29.3644);

/// Map card to pick a real delivery pin (OpenStreetMap), not a store chip.
class DeliveryMapCard extends StatefulWidget {
  const DeliveryMapCard({
    super.key,
    required this.selectedAddress,
    required this.onPicked,
  });

  final String selectedAddress;
  final ValueChanged<String> onPicked;

  @override
  State<DeliveryMapCard> createState() => _DeliveryMapCardState();
}

class _DeliveryMapCardState extends State<DeliveryMapCard> {
  final _mapController = MapController();
  final _addressCtrl = TextEditingController();
  final _http = http.Client();

  LatLng _pin = kDefaultDeliveryCenter;
  String _label = '';
  bool _resolving = false;
  bool _locating = false;
  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    final existing = widget.selectedAddress.trim();
    if (existing.isNotEmpty) {
      _addressCtrl.text = existing;
      _label = existing;
      final parsed = _parseLatLng(existing);
      if (parsed != null) _pin = parsed;
    }
    unawaited(_bootstrapLocation());
  }

  @override
  void didUpdateWidget(covariant DeliveryMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.selectedAddress.trim();
    if (next != oldWidget.selectedAddress.trim() && next != _addressCtrl.text.trim()) {
      _addressCtrl.text = next;
      _label = next;
      final parsed = _parseLatLng(next);
      if (parsed != null) {
        _pin = parsed;
        try {
          _mapController.move(_pin, _mapController.camera.zoom);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _addressCtrl.dispose();
    _mapController.dispose();
    _http.close();
    super.dispose();
  }

  Future<void> _bootstrapLocation() async {
    if (widget.selectedAddress.trim().isNotEmpty) return;
    setState(() => _locating = true);
    try {
      final pos = await _currentPosition();
      if (!mounted || pos == null) return;
      _pin = LatLng(pos.latitude, pos.longitude);
      _mapController.move(_pin, 15);
      await _resolveAndCommit(_pin);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<Position?> _currentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) return null;
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await _currentPosition();
      if (!mounted) return;
      if (pos == null) return;
      _pin = LatLng(pos.latitude, pos.longitude);
      _mapController.move(_pin, 16);
      await _resolveAndCommit(_pin);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() => _pin = point);
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_resolveAndCommit(point));
    });
  }

  Future<void> _resolveAndCommit(LatLng point) async {
    if (!mounted) return;
    setState(() => _resolving = true);
    final fallback =
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    var address = fallback;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'zoom': '18',
        'addressdetails': '0',
      });
      final response = await _http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'ITARA-POS/1.0 (delivery-picker)',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['display_name'] is String) {
          final name = (body['display_name'] as String).trim();
          if (name.isNotEmpty) address = name;
        }
      }
    } catch (_) {
      // Keep coordinate fallback when offline / geocode fails.
    }
    if (address.length > 255) address = address.substring(0, 255);
    if (!mounted) return;
    setState(() {
      _label = address;
      _addressCtrl.text = address;
      _resolving = false;
    });
    widget.onPicked(address);
  }

  void _commitTypedAddress() {
    final value = _addressCtrl.text.trim();
    if (value.isEmpty) return;
    final clipped = value.length > 255 ? value.substring(0, 255) : value;
    setState(() => _label = clipped);
    widget.onPicked(clipped);
  }

  LatLng? _parseLatLng(String raw) {
    final match = RegExp(r'(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(raw);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _label.trim().isNotEmpty || widget.selectedAddress.trim().isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosUi.deskCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosUi.deskAccent.withValues(alpha: 0.55)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.map_outlined, size: 18, color: PosUi.deskAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Adresse de livraison'),
                    style: PosUi.cardTitle(color: PosUi.deskText).copyWith(fontSize: 16),
                  ),
                ),
                TextButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: Text(tr('Ma position')),
                  style: TextButton.styleFrom(
                    foregroundColor: PosUi.deskAccent,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('Touchez la carte pour placer le point de livraison.'),
              style: PosUi.body(color: PosUi.deskMuted),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _pin,
                        initialZoom: 14,
                        minZoom: 3,
                        maxZoom: 19,
                        onTap: _onMapTap,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.itara.pos_mobile',
                          maxNativeZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pin,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                size: 44,
                                color: Color(0xFFE11D48),
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_resolving)
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              style: AppTypography.text(fontSize: 13, color: PosUi.deskText),
              decoration: InputDecoration(
                hintText: tr('Adresse ou lieu exact…'),
                hintStyle: AppTypography.text(fontSize: 13, color: PosUi.deskMuted),
                filled: true,
                fillColor: PosUi.deskField,
                prefixIcon: Icon(Icons.place_outlined, color: PosUi.deskAccent, size: 20),
                suffixIcon: IconButton(
                  tooltip: tr('Valider'),
                  onPressed: _commitTypedAddress,
                  icon: Icon(Icons.check_circle_outline, color: PosUi.deskAccent),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: PosUi.deskLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: PosUi.deskLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: PosUi.deskAccent),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitTypedAddress(),
            ),
            if (hasSelection) ...[
              const SizedBox(height: 8),
              Text(
                trf('Livraison vers : {0}', [
                  _label.trim().isEmpty ? widget.selectedAddress.trim() : _label.trim(),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PosUi.body(color: PosUi.deskAccent, weight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
