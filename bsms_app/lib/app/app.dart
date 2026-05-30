import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../data/ble/ecg_ble_service.dart';
import '../data/ble/ecg_packet_parser.dart';
import '../data/ble/ble_recording_service.dart';
import '../data/storage/database_helper.dart';
import '../data/storage/imported_session_repository.dart';
import '../data/storage/person_repository.dart';
import '../data/storage/session_storage_service.dart';
import '../presentation/history/history_screen.dart';
import '../presentation/live_ecg/live_ecg_screen.dart';
import '../presentation/permissions/permission_gate.dart';
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
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Follow the phone language; fall back to English for any unlisted locale.
      localeListResolutionCallback: (deviceLocales, supported) {
        if (deviceLocales != null) {
          for (final device in deviceLocales) {
            for (final s in supported) {
              if (s.languageCode == device.languageCode) return s;
            }
          }
        }
        return const Locale('en');
      },
      home: const PermissionGate(child: _BsmsHome()),
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.monitor_heart_outlined),
            selectedIcon: const Icon(Icons.monitor_heart),
            label: context.l10n.navLive,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: context.l10n.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: context.l10n.navPersons,
          ),
        ],
      ),
    );
  }
}
