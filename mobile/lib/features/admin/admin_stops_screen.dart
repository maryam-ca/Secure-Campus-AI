import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/bus_route.dart';
import '../../core/utils/save_error.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/section_card.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';
import 'map_picker_screen.dart';

/// Admin > Transport > Stops: the bus route, stop by stop, in the order the
/// bus visits them, with arrows showing the direction of travel.
class AdminStopsScreen extends ConsumerWidget {
  const AdminStopsScreen({super.key});

  /// Deletes a stop after confirming. A stop that students are assigned to
  /// cannot be deleted: they would be left with a stop that does not exist.
  Future<void> _deleteStop(BuildContext context, WidgetRef ref, List<BusStopModel> stops, BusStopModel stop) async {
    final riders = (ref.read(busAssignmentsProvider).valueOrNull ?? const <AdminBusAssignmentModel>[])
        .where((a) => a.stopId == stop.id)
        .length;
    if (riders > 0) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot delete this stop'),
          content: Text('$riders student${riders == 1 ? ' is' : 's are'} assigned to "${stop.name}". '
              'Remove or move their bus assignments first (Transport > Buses).'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${stop.name}"?',
      message: 'The stop is removed from the route and the stops after it move up one place.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(adminRepositoryProvider).deleteBusStop(stop.id, renumberedAfterRemoving(stops, stop.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopsAsync = ref.watch(busStopsProvider);
    ref.watch(busAssignmentsProvider); // kept loaded so Delete knows which stops have riders

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _RouteMapCard(),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Route',
          icon: Icons.route_outlined,
          child: stopsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load stops.'),
            data: (stops) => stops.isEmpty
                ? const Text('No stops configured yet.')
                : Wrap(
                    key: const Key('route-summary'),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < stops.length; i++) ...[
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: AppColors.primaryBlue,
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                          label: Text(stops[i].name),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (i < stops.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.arrow_forward, size: 18, color: AppColors.primaryBlue),
                          ),
                      ],
                    ],
                  ),
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
                      for (var i = 0; i < stops.length; i++) ...[
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
                              IconButton(
                                key: Key('stop-delete-$i'),
                                tooltip: 'Delete this stop',
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                onPressed: () => _deleteStop(context, ref, stops, stops[i]),
                              ),
                            ],
                          ),
                        ),
                        // arrow showing the bus travels from this stop to the next
                        if (i < stops.length - 1)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 0, bottom: 2),
                              child: Icon(Icons.south, size: 20, color: AppColors.primaryBlue),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Route map: the campus and every stop in order, joined by a line. The first
/// stop is where the morning bus starts. "Add stop" opens a dialog where the
/// place is chosen by tapping the map.
class _RouteMapCard extends ConsumerWidget {
  const _RouteMapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(busStopsProvider).valueOrNull ?? const <BusStopModel>[];
    final campus = ref.watch(campusLocationProvider).valueOrNull;
    final points = routePoints(stops, campus);
    final sorted = [...stops]..sort((a, b) => a.order.compareTo(b.order));

    return SectionCard(
      title: 'Route map',
      icon: Icons.map_outlined,
      trailing: TextButton.icon(
        key: const Key('add-stop-on-map'),
        onPressed: () => showDialog(context: context, builder: (_) => const _AddStopDialog()),
        icon: const Icon(Icons.add_location_alt_outlined, size: 18),
        label: const Text('Add stop'),
      ),
      child: points.isEmpty
          ? const Text('Add the first stop, or set the campus location, to see the route here.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 240,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      key: const Key('route-map'),
                      options: points.length > 1
                          ? MapOptions(
                              initialCameraFit: CameraFit.coordinates(
                                coordinates: points,
                                padding: const EdgeInsets.all(40),
                                maxZoom: 16,
                              ),
                            )
                          : MapOptions(initialCenter: points.first, initialZoom: 15),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.securecampus',
                        ),
                        if (points.length > 1)
                          PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 4, color: AppColors.primaryBlue)]),
                        MarkerLayer(
                          markers: [
                            for (var i = 0; i < sorted.length; i++)
                              Marker(
                                point: LatLng(sorted[i].lat, sorted[i].lng),
                                width: 30,
                                height: 30,
                                child: Tooltip(
                                  message: sorted[i].name,
                                  child: CircleAvatar(
                                    backgroundColor: i == 0 ? AppColors.success : AppColors.primaryBlue,
                                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ),
                              ),
                            if (campus != null)
                              Marker(
                                point: LatLng(campus.lat, campus.lng),
                                width: 36,
                                height: 36,
                                child: Tooltip(
                                  message: campus.name,
                                  child: const Icon(Icons.school, color: AppColors.error, size: 32),
                                ),
                              ),
                          ],
                        ),
                        RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sorted.isEmpty
                      ? 'Only the campus is set. Add stops to build the route.'
                      : 'Green = where the morning bus starts (stop 1). The line runs stop by stop to the campus.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
    );
  }
}

class _AddStopDialog extends ConsumerStatefulWidget {
  const _AddStopDialog();

  @override
  ConsumerState<_AddStopDialog> createState() => _AddStopDialogState();
}

class _AddStopDialogState extends ConsumerState<_AddStopDialog> {
  final _name = TextEditingController();
  LatLng? _location;
  bool _submitting = false;
  String? _error;

  /// Lets the Admin choose the place by tapping the map (or "my location").
  Future<void> _pickOnMap() async {
    final stops = ref.read(busStopsProvider).valueOrNull ?? const <BusStopModel>[];
    final campus = ref.read(campusLocationProvider).valueOrNull;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'Choose the stop location',
          initial: _location,
          around: stops.isNotEmpty
              ? LatLng(stops.last.lat, stops.last.lng)
              : (campus != null ? LatLng(campus.lat, campus.lng) : null),
          others: [
            for (final s in stops) LatLng(s.lat, s.lng),
            if (campus != null) LatLng(campus.lat, campus.lng),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _location = picked);
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name for the stop.');
      return;
    }
    if (_location == null) {
      setState(() => _error = 'Choose the stop location on the map.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final stops = ref.read(busStopsProvider).valueOrNull ?? const <BusStopModel>[];
      await ref.read(adminRepositoryProvider).upsertBusStop(
            nextStopId(stops.map((s) => s.id)),
            _name.text.trim(),
            _location!.latitude,
            _location!.longitude,
            nextStopOrder(stops),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = saveFailureMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = ref.watch(busStopsProvider).valueOrNull ?? const <BusStopModel>[];
    return AlertDialog(
      title: const Text('Add Bus Stop'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('stop-name-field'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Stop name (e.g. Main Chowk)'),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('stop-pick-on-map'),
              onPressed: _pickOnMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(_location == null ? 'Choose location on map' : 'Change location on map'),
            ),
            const SizedBox(height: 6),
            Text(
              _location == null
                  ? 'No location chosen yet.'
                  : 'Location: ${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}',
              key: const Key('stop-location-text'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              stops.isEmpty
                  ? 'This will be stop 1, where the morning bus starts.'
                  : 'It is added at the end of the route (stop ${nextStopOrder(stops)}). Use the arrows to move it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const Key('stop-save-error'), style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          key: const Key('stop-add'),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Add'),
        ),
      ],
    );
  }
}
