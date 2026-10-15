import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/roles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/driver_status.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/driver_repository.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) => DriverRepository());

/// The clock the screen uses (overridable in tests).
final driverClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Where GPS fixes come from. A seam so the screen is tested without a phone.
abstract class DriverLocationSource {
  /// A plain-language problem that stops a trip from starting, or null if ready.
  Future<String?> checkReady();

  /// Live fixes. On Android this runs as a foreground service (a notification
  /// is shown) so the location keeps flowing with the screen off or the app in
  /// the background, and a fix is delivered every ~10 seconds even when the
  /// bus is standing still.
  Stream<Position> positions();
}

class GeolocatorLocationSource implements DriverLocationSource {
  const GeolocatorLocationSource();

  @override
  Future<String?> checkReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Location is turned off on this phone. Turn on GPS and try again.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      return 'Location access is blocked for SecureCampus. Allow it in Settings > Apps > SecureCampus > Permissions.';
    }
    if (permission == LocationPermission.denied) {
      return 'Location permission was denied. Allow it to share the bus location.';
    }
    return null;
  }

  @override
  Stream<Position> positions() {
    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'SecureCampus trip is live',
              notificationText: 'Sharing the bus location with students.',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

final driverLocationSourceProvider = Provider<DriverLocationSource>((ref) => const GeolocatorLocationSource());

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
  Timer? _ticker;
  Position? _lastPosition;
  DateTime? _lastFix;
  DateTime? _tripStartedAt;
  late DateTime _now = ref.read(driverClockProvider)();
  String? _tripId;
  String? _error;
  String? _notice;
  bool _writeFailing = false;

  @override
  void initState() {
    super.initState();
    _loadBus();
  }

  Future<void> _loadBus() async {
    // Wait for the signed-in user instead of reading it once: if this screen
    // opens before the auth stream has emitted, a one-time read would leave
    // the spinner up forever.
    final user = await ref.read(firebaseAuthStateProvider.future);
    final uid = user?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingBus = false);
      return;
    }
    final repo = ref.read(driverRepositoryProvider);
    String? busId;
    String? notice;
    try {
      busId = await repo.fetchAssignedBusId(uid);
      // The app was closed during a trip: the database still says "active" but
      // nothing is sending locations. End it so students are not misled.
      if (busId != null && await repo.isTripMarkedActive(busId)) {
        await repo.markTripStopped(busId: busId, tripId: '');
        notice = 'A trip from earlier was still marked live (the app had been closed). It has been ended. '
            'Start a new trip when you are ready.';
      }
    } catch (e) {
      _error = friendlyDriverError(e);
    }
    if (mounted) {
      setState(() {
        _busId = busId;
        _notice = notice;
        _loadingBus = false;
      });
    }
  }

  Future<void> _startTrip() async {
    if (_busId == null) return;
    setState(() {
      _error = null;
      _notice = null;
      _tripState = _TripState.starting;
    });

    final problem = await ref.read(driverLocationSourceProvider).checkReady();
    if (problem != null) {
      if (mounted) {
        setState(() {
          _error = problem;
          _tripState = _TripState.idle;
        });
      }
      return;
    }

    final repo = ref.read(driverRepositoryProvider);
    _tripId = DateTime.now().millisecondsSinceEpoch.toString();
    _writeFailing = false;
    try {
      await repo.armAutoEnd(_busId!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyDriverError(e);
          _tripState = _TripState.idle;
        });
      }
      return;
    }

    _positionSub = ref.read(driverLocationSourceProvider).positions().listen(
      (position) async {
        // A fix that arrives after the trip was ended must not re-mark it live.
        if (_tripState != _TripState.active) return;
        _lastPosition = position;
        _lastFix = ref.read(driverClockProvider)();
        try {
          await repo.pushLocation(
            busId: _busId!,
            lat: position.latitude,
            lng: position.longitude,
            tripActive: true,
            tripId: _tripId!,
          );
          if (_writeFailing && mounted) setState(() {
            _writeFailing = false;
            _error = null;
          });
        } catch (e) {
          _writeFailing = true;
          if (mounted) setState(() => _error = friendlyDriverError(e));
        }
        if (mounted) setState(() {});
      },
      onError: (Object e) {
        // GPS trouble does not end the trip: the warning below tells the driver,
        // and the fix resumes by itself when GPS comes back.
        if (mounted) setState(() => _error = friendlyDriverError(e));
      },
    );

    _tripStartedAt = ref.read(driverClockProvider)();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = ref.read(driverClockProvider)());
    });
    if (mounted) setState(() => _tripState = _TripState.active);
  }

  Future<void> _stopTrip() async {
    if (_tripState == _TripState.idle) return;
    if (mounted) setState(() => _tripState = _TripState.stopping);
    // Not awaited: the trip is ended in the database below regardless, and a
    // slow cancel must never leave the screen stuck on "Ending...".
    final sub = _positionSub;
    _positionSub = null;
    if (sub != null) unawaited(sub.cancel());
    _ticker?.cancel();
    _ticker = null;

    if (_busId != null && _tripId != null) {
      try {
        await ref.read(driverRepositoryProvider).markTripStopped(busId: _busId!, tripId: _tripId!);
      } catch (e) {
        if (mounted) setState(() => _error = friendlyDriverError(e));
      }
    }

    if (mounted) {
      setState(() {
        _tripState = _TripState.idle;
        _tripStartedAt = null;
      });
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _tripState == _TripState.active || _tripState == _TripState.stopping;
    final stuck = _tripState == _TripState.active && gpsLooksStuck(_lastFix, _now);

    return PortalScaffold(
      title: 'Driver',
      role: UserRole.driver,
      // Signing out must not leave a live trip behind.
      onBeforeSignOut: _stopTrip,
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
                                _TripState.active => 'LIVE: sharing location',
                                _TripState.stopping => 'Ending...',
                              },
                              color: _tripState == _TripState.active ? AppColors.success : AppColors.bodyText,
                            ),
                            if (_tripStartedAt != null)
                              _StatusRow(label: 'Trip time', value: tripTimerLabel(_now.difference(_tripStartedAt!))),
                            _StatusRow(
                              label: 'Location',
                              value: _lastPosition == null
                                  ? (active ? 'Waiting for GPS...' : 'Not sharing')
                                  : '${_lastPosition!.latitude.toStringAsFixed(5)}, ${_lastPosition!.longitude.toStringAsFixed(5)}',
                              color: _lastPosition == null ? AppColors.warning : AppColors.navyText,
                            ),
                            if (_lastFix != null)
                              _StatusRow(
                                key: const Key('gps-age'),
                                label: 'Last GPS update',
                                value: gpsAgeLabel(_lastFix, _now) ?? '',
                                color: stuck ? AppColors.error : null,
                              ),
                            if (stuck)
                              const _Banner(
                                key: Key('gps-stuck'),
                                color: AppColors.error,
                                text: 'No new GPS location for a while. Students are not getting live updates. '
                                    'Check that GPS is on and you have a signal.',
                              ),
                            if (_notice != null) _Banner(color: AppColors.warning, text: _notice!),
                            if (_error != null) _Banner(key: const Key('driver-error'), color: AppColors.error, text: _error!),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: active
                                  ? ElevatedButton.icon(
                                      onPressed: _tripState == _TripState.stopping
                                          ? null
                                          : () async {
                                              final confirmed = await showConfirmDialog(
                                                context,
                                                title: 'End this trip?',
                                                message: 'Location sharing will stop and students will stop '
                                                    'getting 20- and 10-minute bus alerts for this trip.',
                                                confirmLabel: 'End Trip',
                                              );
                                              if (confirmed) await _stopTrip();
                                            },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                      icon: const Icon(Icons.stop_circle_outlined),
                                      label: const Text('End Trip'),
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

class _Banner extends StatelessWidget {
  final Color color;
  final String text;
  const _Banner({super.key, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatusRow({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600, color: color ?? AppColors.navyText),
            ),
          ),
        ],
      ),
    );
  }
}
