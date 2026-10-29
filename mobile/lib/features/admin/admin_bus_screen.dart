import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/save_error.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/section_card.dart';
import '../../models/student_model.dart';
import '../../models/transport_models.dart';
import '../../providers/admin_providers.dart';
import 'map_picker_screen.dart';

const _busId = 'BUS-001'; // spec §29 - exactly one bus

/// Admin > Transport > Buses: live map, status, the campus location, and which
/// students ride. The stops and their order are on the Stops page.
class AdminBusScreen extends ConsumerWidget {
  const AdminBusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopsAsync = ref.watch(busStopsProvider);
    final assignmentsAsync = ref.watch(busAssignmentsProvider);
    final locationAsync = ref.watch(driverLocationProvider(_busId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Live Map — $_busId',
          icon: Icons.map_outlined,
          child: locationAsync.when(
            loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => const SizedBox(
              height: 80,
              child: Center(child: Text('Could not load live location.')),
            ),
            data: (location) {
              final lat = (location?['lat'] as num?)?.toDouble();
              final lng = (location?['lng'] as num?)?.toDouble();
              final tripActive = location?['tripActive'] as bool? ?? false;
              final updatedAtMs = (location?['updatedAt'] as num?)?.toInt();

              if (lat == null || lng == null) {
                return const SizedBox(
                  height: 160,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_off_outlined, color: AppColors.warning, size: 32),
                        SizedBox(height: 8),
                        Text('GPS UNAVAILABLE', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                        Text('No driver location on file yet.'),
                      ],
                    ),
                  ),
                );
              }

              final stops = stopsAsync.valueOrNull ?? [];
              final updatedAt = updatedAtMs != null
                  ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs)
                  : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 260,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      // OpenStreetMap tiles: free, no API key, no billing account.
                      child: FlutterMap(
                        options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 13),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.securecampus',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final s in stops)
                                Marker(
                                  point: LatLng(s.lat, s.lng),
                                  width: 36,
                                  height: 36,
                                  child: Tooltip(
                                    message: s.name,
                                    child: const Icon(Icons.location_on, color: AppColors.success, size: 32),
                                  ),
                                ),
                              Marker(
                                point: LatLng(lat, lng),
                                width: 44,
                                height: 44,
                                child: Tooltip(
                                  message: tripActive ? '$_busId - trip active' : '$_busId - idle',
                                  child: const Icon(Icons.directions_bus_filled, color: AppColors.primaryBlue, size: 36),
                                ),
                              ),
                            ],
                          ),
                          const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(tripActive ? Icons.directions_bus_filled : Icons.directions_bus_filled_outlined,
                          size: 16, color: tripActive ? AppColors.success : AppColors.bodyText),
                      const SizedBox(width: 6),
                      Text(tripActive ? 'Trip Active' : 'Idle', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (updatedAt != null)
                        Text('Last update: ${updatedAt.toLocal().toString().substring(11, 19)}',
                            style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Bus Status — $_busId',
          icon: Icons.directions_bus_filled_outlined,
          child: FutureBuilder<String>(
            future: ref.read(adminRepositoryProvider).fetchBusStatus(_busId),
            builder: (context, snap) => Text(snap.data ?? 'Loading...', style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Campus Location',
          icon: Icons.school_outlined,
          child: Builder(builder: (context) {
            final campus = ref.watch(campusLocationProvider).valueOrNull;
            return ListTile(
              key: const Key('campus-tile'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school_outlined, size: 20),
              title: Text(campus == null ? 'Campus location not set' : campus.name),
              subtitle: Text(campus == null
                  ? 'Needed for to-campus and from-campus trips.'
                  : '${campus.lat}, ${campus.lng}'),
              trailing: TextButton(
                onPressed: () => showDialog(context: context, builder: (_) => _CampusDialog(current: campus)),
                child: Text(campus == null ? 'Set' : 'Change'),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Student Bus Assignments',
          icon: Icons.assignment_ind_outlined,
          trailing: TextButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => const _AssignStudentDialog()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Assign'),
          ),
          child: assignmentsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load assignments.'),
            data: (assignments) => assignments.isEmpty
                ? const Text('No students assigned yet.')
                : Column(
                    children: assignments
                        .map((a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(a.studentName),
                              subtitle: Text('Stop: ${a.stopName}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                onPressed: () async {
                                  final confirmed = await showConfirmDialog(
                                    context,
                                    title: 'Remove bus assignment?',
                                    message: '${a.studentName} will no longer see this bus or get the '
                                        'the 10-minute arrival alert for ${a.stopName}.',
                                    confirmLabel: 'Remove',
                                  );
                                  if (confirmed) {
                                    await ref.read(adminRepositoryProvider).removeBusAssignment(a.id);
                                  }
                                },
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CampusDialog extends ConsumerStatefulWidget {
  final CampusLocation? current;
  const _CampusDialog({this.current});

  @override
  ConsumerState<_CampusDialog> createState() => _CampusDialogState();
}

class _CampusDialogState extends ConsumerState<_CampusDialog> {
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

class _AssignStudentDialog extends ConsumerStatefulWidget {
  const _AssignStudentDialog();

  @override
  ConsumerState<_AssignStudentDialog> createState() => _AssignStudentDialogState();
}

class _AssignStudentDialogState extends ConsumerState<_AssignStudentDialog> {
  StudentModel? _student;
  String? _stopId;
  String? _stopName;
  String? _error;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_student == null || _stopId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).assignStudentToBus(
            studentId: _student!.uid,
            studentName: _student!.name,
            busId: _busId,
            stopId: _stopId!,
            stopName: _stopName!,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Stay on the dialog and say why it was not saved.
      if (mounted) setState(() => _error = saveFailureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(allStudentsProvider);
    final stopsAsync = ref.watch(busStopsProvider);

    return AlertDialog(
      title: const Text('Assign Student to Bus'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            studentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load students.'),
              data: (students) => DropdownButtonFormField<StudentModel>(
                value: _student,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Student'),
                items: students
                    .map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.registrationNumber})', overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _student = v),
              ),
            ),
            const SizedBox(height: 12),
            stopsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load stops.'),
              data: (stops) => DropdownButtonFormField<String>(
                value: _stopId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Registered stop'),
                items: stops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() {
                  _stopId = v;
                  _stopName = stops.firstWhere((s) => s.id == v).name;
                }),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const Key('assign-error'), style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Assign'),
        ),
      ],
    );
  }
}
