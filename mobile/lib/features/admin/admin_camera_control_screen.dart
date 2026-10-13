import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/portal_scaffold.dart';
import '../../providers/admin_providers.dart';
import '../../services/backend_api_service.dart';

/// Talks directly to the iris_ai service (not Firestore) - this is the
/// one Admin screen that reaches the camera/recognition backend
/// directly, since "is the camera online" and "is the recognition loop
/// running" are facts that live on that service, not in Firestore.
/// Fixes audit finding §C: previously the only way to start/stop the
/// live recognition loop was a manual curl call.
class AdminCameraControlScreen extends ConsumerStatefulWidget {
  const AdminCameraControlScreen({super.key});

  @override
  ConsumerState<AdminCameraControlScreen> createState() => _AdminCameraControlScreenState();
}

class _AdminCameraControlScreenState extends ConsumerState<AdminCameraControlScreen> {
  Map<String, dynamic>? _camera;
  Map<String, dynamic>? _stream;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(backendApiServiceProvider);
      final results = await Future.wait([api.fetchCameraStatus(), api.fetchStreamStatus()]);
      setState(() {
        _camera = results[0];
        _stream = results[1];
      });
    } on BackendApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not reach the iris_ai service. Is it running? ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start(String mode) async {
    setState(() => _busy = true);
    try {
      await ref.read(backendApiServiceProvider).startStream(mode);
    } on BackendApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await ref.read(backendApiServiceProvider).stopStream();
    } on BackendApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final cameraOnline = _camera?['status'] == 'ONLINE';
    final running = _stream?['running'] == true;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              color: AppColors.error.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Camera',
            icon: Icons.videocam_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Name', _camera?['name'] ?? '—'),
                _row('Location', _camera?['location'] ?? '—'),
                _row(
                  'Status',
                  _camera?['status'] ?? 'UNKNOWN',
                  color: cameraOnline ? AppColors.success : AppColors.warning,
                ),
                _row('Detail', _camera?['detail'] ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Recognition Loop',
            icon: Icons.face_retouching_natural_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                  'Status',
                  running ? 'RUNNING (mode: ${_stream?['mode']})' : 'STOPPED',
                  color: running ? AppColors.success : AppColors.bodyText,
                ),
                const SizedBox(height: 16),
                if (running)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _stop,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Stop Recognition'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _start('attendance'),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Start: Attendance'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _start('gate'),
                          icon: const Icon(Icons.login_outlined),
                          label: const Text('Start: Gate'),
                        ),
                      ),
                    ],
                  ),
                if (_busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This talks directly to the iris_ai service configured at the app\'s '
            'BACKEND_BASE_URL build setting - not through Firestore.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.bodyText)),
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
