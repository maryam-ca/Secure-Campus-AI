import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/save_error.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/section_card.dart';
import '../../models/student_model.dart';
import '../../providers/admin_providers.dart';

const _busId = 'BUS-001'; // spec §29 - exactly one bus

/// Admin > Transport > Buses: live map, status, and which students ride. The
/// stops, their order and the campus (the last stop of the morning route) are
/// on the Stops page.
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
