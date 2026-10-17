import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/bus_route.dart';
import '../../core/utils/save_error.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';

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
  String? _error;

  Future<void> _submit() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (_id.text.trim().isEmpty || _name.text.trim().isEmpty || lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      setState(() => _error = 'Enter an ID, a name, and a valid latitude (-90 to 90) and longitude (-180 to 180).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).upsertBusStop(
            _id.text.trim(), _name.text.trim(), lat, lng, int.tryParse(_order.text.trim()) ?? 1,
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
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Add'),
        ),
      ],
    );
  }
}
