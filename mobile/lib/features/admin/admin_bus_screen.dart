import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../models/student_model.dart';
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
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 13),
                        markers: {
                          Marker(
                            markerId: const MarkerId('bus'),
                            position: LatLng(lat, lng),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            infoWindow: InfoWindow(title: _busId, snippet: tripActive ? 'Trip active' : 'Idle'),
                          ),
                          for (final s in stops)
                            Marker(
                              markerId: MarkerId('stop_${s.id}'),
                              position: LatLng(s.lat, s.lng),
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                              infoWindow: InfoWindow(title: s.name),
                            ),
                        },
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
                    children: stops
                        .map((s) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.location_on_outlined, size: 18),
                              title: Text(s.name),
                              subtitle: Text('${s.lat}, ${s.lng}'),
                            ))
                        .toList(),
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
                                        '10-minute arrival notification for ${a.stopName}.',
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
  bool _submitting = false;

  Future<void> _submit() async {
    if (_student == null || _stopId == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).assignStudentToBus(
            studentId: _student!.uid,
            studentName: _student!.name,
            busId: _busId,
            stopId: _stopId!,
            stopName: _stopName!,
          );
      if (mounted) Navigator.of(context).pop();
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
