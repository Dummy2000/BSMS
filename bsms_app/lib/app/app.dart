import 'package:flutter/material.dart';
import '../data/ble/ecg_ble_service.dart';
import '../data/ble/ecg_packet_parser.dart';
import '../data/ble/ecg_packet.dart';
import '../data/storage/imported_session_repository.dart';
import '../presentation/history/history_screen.dart';

/// Main application widget for the BSMS ECG monitoring system.
/// 
/// Provides:
/// - Material Design theme and styling
/// - Navigation structure for the app
/// - Top-level state management setup
/// 
/// The app will display:
/// - Live ECG screen (primary view)
/// - Device connection screen (setup flow)
/// - Session history list
/// - Settings and about screens
class BsmsApp extends StatelessWidget {
  const BsmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSMS ECG Monitor',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const BsmsHomePage(),
    );
  }
}

/// Home page placeholder for the BSMS app.
/// 
/// This will be replaced with the actual navigation structure
/// once Dev C implements the presentation layer screens.
///
/// TEMPORARY: Includes BLE connection testing functionality
class BsmsHomePage extends StatefulWidget {
  const BsmsHomePage({super.key});

  @override
  State<BsmsHomePage> createState() => _BsmsHomePageState();
}

class _BsmsHomePageState extends State<BsmsHomePage> {
  late final EcgBleService _bleService;
  late final EcgPacketParser _parser;
  final ImportedSessionRepository _importedSessions = ImportedSessionRepository();

  String _connectionStatus = 'Not connected';
  int _packetCount = 0;
  EcgPacket? _lastPacket;

  @override
  void initState() {
    super.initState();
    _parser = EcgPacketParser();
    _bleService = EcgBleService(_parser);

    // Listen to ECG packets
    _bleService.ecgPackets.listen(
      (packet) {
        setState(() {
          _packetCount++;
          _lastPacket = packet;
          _connectionStatus = 'Connected - Receiving data';
        });
      },
      onError: (error) {
        setState(() {
          _connectionStatus = 'Error: $error';
        });
      },
    );
  }

  @override
  void dispose() {
    _bleService.stop();
    super.dispose();
  }

  Future<void> _startBleConnection() async {
    try {
      setState(() {
        _connectionStatus = 'Scanning for ECG device...';
      });

      await _bleService.start();

      setState(() {
        _connectionStatus = 'Connecting...';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Failed to start: $e';
      });
    }
  }

  Future<void> _stopBleConnection() async {
    try {
      await _bleService.stop();
      setState(() {
        _connectionStatus = 'Disconnected';
        _packetCount = 0;
        _lastPacket = null;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error disconnecting: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BSMS ECG Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Importierte Aufnahmen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryScreen(repository: _importedSessions),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BLE Connection Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Connection status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $_connectionStatus'),
                    Text('Packets received: $_packetCount'),
                    if (_lastPacket != null) ...[
                      const SizedBox(height: 8),
                      Text('Last packet:'),
                      Text('  Timestamp: ${_lastPacket!.timestamp}'),
                      Text('  Heart Rate: ${_lastPacket!.heartRate} BPM'),
                      Text('  Flags: 0x${_lastPacket!.flags.toRadixString(16)}'),
                      Text('  Samples: ${_lastPacket!.samples.length}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Control buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: _startBleConnection,
                  child: const Text('Start BLE'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _stopBleConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Stop BLE'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Testing Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Ensure ESP32 with ECG firmware is powered on'),
                    Text('2. Make sure Bluetooth is enabled on this device'),
                    Text('3. Click "Start BLE" to scan and connect'),
                    Text('4. ESP32 should appear as "EKG-Holter"'),
                    Text('5. Connection will auto-sync timestamp and start data'),
                    Text('6. Monitor packet reception in status above'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
