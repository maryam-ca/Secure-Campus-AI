import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/roles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/driver_repository.dart';

final _driverRepositoryProvider = Provider<DriverRepository>((ref) => DriverRepository());

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

enum _TripState { idle, starting, active, stopping }

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  String? _busId;
  bool _loadingBus = true;
  _TripState _tripState = _TripState.idle;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  DateTime? _lastUpdate;
  String? _tripId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBus();
  }

  Future<void> _loadBus() async {
    final uid = ref.read(firebaseAuthStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final busId = await ref.read(_driverRepositoryProvider).fetchAssignedBusId(uid);
    if (mounted) {
      setState(() {
        _busId = busId;
        _loadingBus = false;
      });
    }
  }

  Future<void> _startTrip() async {
    if (_busId == null) return;
    setState(() {
      _error = null;
      _tripState = _TripState.starting;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = 'Location services are turned off on this device. Please enable GPS and try again.';
        _tripState = _TripState.idle;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() {
        _error = 'Location permission was denied. Grant location access to SecureCampus in your device settings.';
        _tripState = _TripState.idle;
      });
      return;
    }

    _tripId = DateTime.now().millisecondsSinceEpoch.toString();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen(
      (position) async {
        _lastPosition = position;
        _lastUpdate = DateTime.now();
        try {
          await ref.read(_driverRepositoryProvider).pushLocation(
                busId: _busId!,
                lat: position.latitude,
                lng: position.longitude,
                tripActive: true,
                tripId: _tripId!,
              );
        } catch (e) {
          if (mounted) setState(() => _error = 'Could not update location: $e');
        }
        if (mounted) setState(() {});
      },
      onError: (Object e) {
        if (mounted) {
          setState(() => _error = 'GPS stream error: $e');
          _stopTrip();
        }
      },
    );

    setState(() => _tripState = _TripState.active);
  }

  Future<void> _stopTrip() async {
    setState(() => _tripState = _TripState.stopping);
    await _positionSub?.cancel();
    _positionSub = null;

    if (_busId != null && _tripId != null) {
      try {
        await ref.read(_driverRepositoryProvider).markTripStopped(busId: _busId!, tripId: _tripId!);
      } catch (e) {
        setState(() => _error = 'Could not update trip status: $e');
      }
    }

    if (mounted) setState(() => _tripState = _TripState.idle);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(
      title: 'Driver',
      role: UserRole.driver,
      body: _loadingBus
          ? const Center(child: CircularProgressIndicator())
          : _busId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('You are not currently assigned to a bus. Contact Admin.', textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.directions_bus_filled_outlined, color: AppColors.primaryBlue, size: 28),
                              const SizedBox(width: 10),
                              Text(_busId!, style: Theme.of(context).textTheme.titleLarge),
                            ]),
                            const SizedBox(height: 16),
                            _StatusRow(
                              label: 'Trip status',
                              value: switch (_tripState) {
                                _TripState.idle => 'Not started',
                                _TripState.starting => 'Starting...',
                                _TripState.active => 'ACTIVE — sharing live location',
                                _TripState.stopping => 'Stopping...',
                              },
                              color: _tripState == _TripState.active ? AppColors.success : AppColors.bodyText,
                            ),
                            _StatusRow(
                              label: 'Current location',
                              value: _lastPosition == null
                                  ? 'GPS UNAVAILABLE'
                                  : '${_lastPosition!.latitude.toStringAsFixed(5)}, ${_lastPosition!.longitude.toStringAsFixed(5)}',
                              color: _lastPosition == null ? AppColors.warning : AppColors.navyText,
                            ),
                            if (_lastUpdate != null)
                              _StatusRow(label: 'Last updated', value: _lastUpdate!.toLocal().toString().substring(11, 19)),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(color: AppColors.error)),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: _tripState == _TripState.active || _tripState == _TripState.stopping
                                  ? ElevatedButton.icon(
                                      onPressed: _tripState == _TripState.stopping
                                          ? null
                                          : () async {
                                              final confirmed = await showConfirmDialog(
                                                context,
                                                title: 'Stop this trip?',
                                                message: 'Location sharing will stop immediately and students '
                                                    'will no longer receive the 10-minute arrival alert for this trip.',
                                                confirmLabel: 'Stop Trip',
                                              );
                                              if (confirmed) await _stopTrip();
                                            },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                      icon: const Icon(Icons.stop_circle_outlined),
                                      label: const Text('Stop Trip'),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _tripState == _TripState.starting ? null : _startTrip,
                                      icon: const Icon(Icons.play_circle_outline),
                                      label: const Text('Start Trip'),
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

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatusRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? AppColors.navyText)),
        ],
      ),
    );
  }
}
