import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/bus_capacity.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../models/student_model.dart';
import '../../models/transport_models.dart';
import '../../providers/admin_providers.dart';

const _busId = 'BUS-001'; // spec §29 - exactly one bus

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
          title: 'Seats & Campus',
          icon: Icons.event_seat_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                key: const Key('seats-tile'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_seat_outlined, size: 20),
                title: Text(seatSummary(
                  capacity: ref.watch(busInfoProvider(_busId)).valueOrNull?.capacity,
                  assigned: assignmentsAsync.valueOrNull?.length ?? 0,
                )),
                subtitle: const Text('A full bus cannot take more students.'),
                trailing: TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _SeatsDialog(current: ref.read(busInfoProvider(_busId)).valueOrNull?.capacity),
                  ),
                  child: const Text('Set seats'),
                ),
              ),
              Builder(builder: (context) {
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Bus Stops',
          icon: Icons.pin_drop_outlined,
          trailing: TextButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => const _AddStopDialog()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Stop'),
          ),
          child: stopsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load stops.'),
            data: (stops) => stops.isEmpty
                ? const Text('No stops configured yet.')
                : Column(
                    children: [
                      for (var i = 0; i < stops.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                          title: Text(stops[i].name),
                          subtitle: Text('${stops[i].lat}, ${stops[i].lng}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: Key('stop-up-$i'),
                                tooltip: 'Earlier on the route',
                                icon: const Icon(Icons.arrow_upward, size: 18),
                                onPressed: i == 0
                                    ? null
                                    : () => ref.read(adminRepositoryProvider).applyStopOrder(reorderedStops(stops, i, -1)),
                              ),
                              IconButton(
                                key: Key('stop-down-$i'),
                                tooltip: 'Later on the route',
                                icon: const Icon(Icons.arrow_downward, size: 18),
                                onPressed: i == stops.length - 1
                                    ? null
                                    : () => ref.read(adminRepositoryProvider).applyStopOrder(reorderedStops(stops, i, 1)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
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
                                        '20- and 10-minute arrival alerts for ${a.stopName}.',
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

class _SeatsDialog extends ConsumerStatefulWidget {
  final int? current;
  const _SeatsDialog({this.current});

  @override
  ConsumerState<_SeatsDialog> createState() => _SeatsDialogState();
}

class _SeatsDialogState extends ConsumerState<_SeatsDialog> {
  late final _seats = TextEditingController(text: widget.current?.toString() ?? '');
  String? _error;

  Future<void> _save() async {
    final n = int.tryParse(_seats.text.trim());
    if (n == null || n < 1 || n > 200) {
      setState(() => _error = 'Enter a whole number from 1 to 200.');
      return;
    }
    await ref.read(adminRepositoryProvider).setBusCapacity(_busId, n);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seating capacity'),
      content: TextField(
        key: const Key('seats-field'),
        controller: _seats,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Number of seats', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
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
  String? _error;

  Future<void> _save() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (_name.text.trim().isEmpty || lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      setState(() => _error = 'Enter a name and valid latitude (-90..90) and longitude (-180..180).');
      return;
    }
    await ref.read(adminRepositoryProvider).setCampus(_name.text.trim(), lat, lng);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true, signed: true);
    return AlertDialog(
      title: const Text('Campus location'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Campus name')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _lat, keyboardType: decimal, decoration: const InputDecoration(labelText: 'Latitude'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _lng, keyboardType: decimal, decoration: const InputDecoration(labelText: 'Longitude'))),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
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

class _AddStopDialog extends ConsumerStatefulWidget {
  const _AddStopDialog();

  @override
  ConsumerState<_AddStopDialog> createState() => _AddStopDialogState();
}

class _AddStopDialogState extends ConsumerState<_AddStopDialog> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _order = TextEditingController(text: '1');
  bool _submitting = false;

  Future<void> _submit() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (_id.text.trim().isEmpty || _name.text.trim().isEmpty || lat == null || lng == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).upsertBusStop(
            _id.text.trim(), _name.text.trim(), lat, lng, int.tryParse(_order.text.trim()) ?? 1,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Bus Stop'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _id, decoration: const InputDecoration(labelText: 'Stop ID (e.g. STOP-04)')),
            const SizedBox(height: 10),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Stop name')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _lng, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _order, decoration: const InputDecoration(labelText: 'Route order (1, 2, 3...)'), keyboardType: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Add'),
        ),
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
    } on StateError catch (e) {
      // Bus full: stay on the dialog and say why.
      if (mounted) setState(() => _error = e.message);
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
