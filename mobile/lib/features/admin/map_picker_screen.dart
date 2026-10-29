import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';

/// Full-screen map where the Admin taps to choose a location (a bus stop, the
/// campus, the route's starting point). Pops with the chosen [LatLng], or null
/// if cancelled. Nothing is saved here: the caller decides what to do with it.
class MapPickerScreen extends StatefulWidget {
  final String title;

  /// Where the pin starts (e.g. the stop being edited). Null = nothing chosen yet.
  final LatLng? initial;

  /// Where to centre the map when nothing is chosen yet (e.g. the campus).
  final LatLng? around;

  /// Already-saved places shown as small grey pins, for context.
  final List<LatLng> others;

  const MapPickerScreen({super.key, required this.title, this.initial, this.around, this.others = const []});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _map = MapController();
  LatLng? _picked;
  String? _message;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  /// Centre: the pin, else the given area, else the first known place, else
  /// the middle of Pakistan (zoomed out so the Admin can find their area).
  (LatLng, double) get _start {
    final c = _picked ?? widget.around ?? (widget.others.isNotEmpty ? widget.others.first : null);
    return c != null ? (c, 15.0) : (const LatLng(30.3753, 69.3451), 5.0);
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location is turned off on this device.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw 'Location permission was not granted.';
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _picked = here);
      _map.move(here, 16);
    } catch (e) {
      if (mounted) {
        setState(() => _message = e is String ? e : 'Could not get your location. Tap the map to choose a place instead.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (center, zoom) = _start;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                    onTap: (tapPosition, point) => setState(() {
                      _picked = point;
                      _message = null;
                    }),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.securecampus',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final o in widget.others)
                          Marker(
                            point: o,
                            width: 28,
                            height: 28,
                            child: const Icon(Icons.location_on, color: Colors.grey, size: 26),
                          ),
                        if (_picked != null)
                          Marker(
                            point: _picked!,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_on, color: AppColors.error, size: 44),
                          ),
                      ],
                    ),
                    RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                  ],
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: FloatingActionButton.small(
                    key: const Key('picker-my-location'),
                    tooltip: 'Use my current location',
                    onPressed: _locating ? null : _useMyLocation,
                    child: _locating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.cardBackground,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _picked == null
                        ? 'Tap the map to place the pin (zoom in for accuracy).'
                        : 'Chosen: ${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                    key: const Key('picker-status'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 6),
                    Text(_message!, key: const Key('picker-message'), style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('picker-use'),
                      onPressed: _picked == null ? null : () => Navigator.of(context).pop(_picked),
                      icon: const Icon(Icons.check),
                      label: const Text('Use this location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
