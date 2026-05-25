import 'package:flutter/material.dart';
import '../data/ble/ecg_ble_service.dart';
import '../data/ble/ecg_packet_parser.dart';
import '../data/ble/ble_recording_service.dart';
import '../data/storage/database_helper.dart';
import '../data/storage/imported_session_repository.dart';
import '../data/storage/person_repository.dart';
import '../data/storage/session_storage_service.dart';
import '../presentation/history/history_screen.dart';
import '../presentation/live_ecg/live_ecg_screen.dart';
import '../presentation/persons/persons_screen.dart';

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
      home: const _BsmsHome(),
    );
  }
}

class _BsmsHome extends StatefulWidget {
  const _BsmsHome();

  @override
  State<_BsmsHome> createState() => _BsmsHomeState();
}

class _BsmsHomeState extends State<_BsmsHome> {
  int _currentIndex = 0;

  // ── Services (created once, shared across screens) ────────────────────────
  final _dbHelper      = DatabaseHelper();
  final _sdRepository  = ImportedSessionRepository();
  final _parser        = EcgPacketParser();

  late final PersonRepository      _personRepository;
  late final SessionStorageService _sessionStorage;
  late final EcgBleService         _bleService;
  late final BleRecordingService   _recordingService;

  @override
  void initState() {
    super.initState();
    _personRepository = PersonRepository(_dbHelper);
    _sessionStorage   = SessionStorageService(_dbHelper);
    _bleService       = EcgBleService(_parser);
    _recordingService = BleRecordingService(_bleService, _sessionStorage);
  }

  @override
  void dispose() {
    _bleService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      LiveEcgScreen(
        bleService:       _bleService,
        recordingService: _recordingService,
        personRepository: _personRepository,
      ),
      HistoryScreen(
        sdRepository:  _sdRepository,
        sessionStorage: _sessionStorage,
      ),
      PersonsScreen(
        personRepository: _personRepository,
        sessionStorage:   _sessionStorage,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Live EKG',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Verlauf',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Personen',
          ),
        ],
      ),
    );
  }
}
