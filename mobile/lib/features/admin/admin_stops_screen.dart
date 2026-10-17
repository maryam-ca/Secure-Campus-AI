import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/bus_capacity.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../providers/admin_providers.dart';

/// Admin > Transport > Stops: the bus route, stop by stop, in the order the
/// bus visits them, with arrows showing the direction of travel.
class AdminStopsScreen extends ConsumerWidget {
  const AdminStopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopsAsync = ref.watch(busStopsProvider);

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
