import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/save_error.dart';
import '../../models/transport_models.dart';
import '../../providers/admin_providers.dart';
import 'map_picker_screen.dart';

/// Sets the campus: name and location (choose on the map, or type coordinates).
/// The campus is a stop of the route: the last one in the morning, the first
/// one in the afternoon. Shown on the Stops page.
class CampusDialog extends ConsumerStatefulWidget {
  final CampusLocation? current;
  const CampusDialog({this.current});

  @override
  ConsumerState<CampusDialog> createState() => _CampusDialogState();
}

class _CampusDialogState extends ConsumerState<CampusDialog> {
  late final _name = TextEditingController(text: widget.current?.name ?? '');
  late final _lat = TextEditingController(text: widget.current?.lat.toString() ?? '');
  late final _lng = TextEditingController(text: widget.current?.lng.toString() ?? '');
  String? _nameError;
  String? _latError;
  String? _lngError;
  String? _saveError;

  /// The coordinate boxes are tucked away: the map is the normal way to choose.
  bool _typing = false;

  bool get _hasLocation {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    return lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;
  }

  /// Choose the campus by tapping the map; fills the latitude/longitude boxes.
  Future<void> _pickOnMap() async {
    final curLat = double.tryParse(_lat.text.trim());
    final curLng = double.tryParse(_lng.text.trim());
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'Choose the campus location',
          initial: curLat != null && curLng != null ? LatLng(curLat, curLng) : null,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _lat.text = picked.latitude.toStringAsFixed(6);
        _lng.text = picked.longitude.toStringAsFixed(6);
        _latError = null;
        _lngError = null;
      });
    }
  }

  Future<void> _save() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    // Say exactly which field is wrong, not one message for all of them.
    final nameError = _name.text.trim().isEmpty ? 'Enter the campus name' : null;
    final latError = (lat == null || lat.abs() > 90) ? 'A number from -90 to 90' : null;
    final lngError = (lng == null || lng.abs() > 180) ? 'A number from -180 to 180' : null;
    if (nameError != null || latError != null || lngError != null) {
      setState(() {
        _nameError = nameError;
        _latError = latError;
        _lngError = lngError;
        _saveError = null;
      });
      return;
    }
    try {
      await ref.read(adminRepositoryProvider).setCampus(_name.text.trim(), lat!, lng!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = saveFailureMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true, signed: true);
    return AlertDialog(
      title: const Text('Campus location'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('campus-name-field'),
            controller: _name,
            decoration: InputDecoration(labelText: 'Campus name', errorText: _nameError),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('campus-pick-on-map'),
              onPressed: _pickOnMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(_hasLocation ? 'Change location on map' : 'Choose location on map'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _hasLocation
                  ? 'Location: ${double.parse(_lat.text.trim()).toStringAsFixed(5)}, ${double.parse(_lng.text.trim()).toStringAsFixed(5)}'
                  : 'No location chosen yet.',
              key: const Key('campus-location-text'),
            ),
          ),
          if (!_typing && (_latError != null || _lngError != null))
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Choose the campus location on the map.',
                    key: Key('campus-location-error'), style: TextStyle(color: AppColors.error)),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('campus-type-coordinates'),
              onPressed: () => setState(() => _typing = !_typing),
              child: Text(_typing ? 'Hide coordinates' : 'Type coordinates instead'),
            ),
          ),
          if (_typing)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  key: const Key('campus-lat-field'),
                  controller: _lat,
                  keyboardType: decimal,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Latitude', errorText: _latError),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('campus-lng-field'),
                  controller: _lng,
                  keyboardType: decimal,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Longitude', errorText: _lngError),
                ),
              ),
            ]),
          if (_saveError != null) ...[
            const SizedBox(height: 10),
            Text(_saveError!, key: const Key('campus-save-error'), style: const TextStyle(color: AppColors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
