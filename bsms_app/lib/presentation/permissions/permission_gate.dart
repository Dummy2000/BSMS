import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/l10n_ext.dart';

class PermissionGate extends StatefulWidget {
  final Widget child;
  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  _GateState _state = _GateState.checking;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when user returns from system settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _state == _GateState.denied) {
      _checkPermissions();
    }
  }

  List<Permission> get _required {
    if (Platform.isAndroid) {
      return [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location, // needed for BLE scan on Android ≤ 11
      ];
    }
    return [Permission.bluetooth];
  }

  Future<void> _checkPermissions() async {
    setState(() { _state = _GateState.checking; _permanentlyDenied = false; });
    final statuses = await Future.wait(_required.map((p) => p.status));
    if (!mounted) return;
    if (statuses.every((s) => s.isGranted)) {
      setState(() => _state = _GateState.granted);
    } else {
      setState(() {
        _state = _GateState.denied;
        _permanentlyDenied = statuses.any((s) => s.isPermanentlyDenied);
      });
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await _required.request();
    if (!mounted) return;
    if (statuses.values.every((s) => s.isGranted)) {
      setState(() => _state = _GateState.granted);
    } else {
      setState(() {
        _state = _GateState.denied;
        _permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _GateState.granted) return widget.child;

    if (_state == _GateState.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // denied
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monitor_heart,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  l.permTitle,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l.permIntro,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _PermTile(
                  icon: Icons.bluetooth,
                  title: l.permBluetooth,
                  description: l.permBluetoothDesc,
                ),
                if (Platform.isAndroid)
                  _PermTile(
                    icon: Icons.location_on_outlined,
                    title: l.permLocation,
                    description: l.permLocationDesc,
                  ),
                if (Platform.isAndroid)
                  _PermTile(
                    icon: Icons.folder_outlined,
                    title: l.permStorage,
                    description: l.permStorageDesc,
                  ),
                const SizedBox(height: 32),
                if (_permanentlyDenied) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.permPermanentlyDenied,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.settings),
                    label: Text(l.permOpenSettings),
                    onPressed: () async {
                      await openAppSettings();
                      // Re-check happens via didChangeAppLifecycleState on resume
                    },
                  ),
                ] else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(l.permGrant),
                    onPressed: _requestPermissions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _GateState { checking, granted, denied }

class _PermTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(description,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
