import 'package:flutter/material.dart';
import '../../data/import/sd_card_import_service.dart';
import '../../data/storage/imported_session_repository.dart';
import '../../data/storage/session_storage_service.dart';
import '../../domain/models/imported_session.dart';
import 'imported_session_screen.dart';

class HistoryScreen extends StatefulWidget {
  final ImportedSessionRepository sdRepository;
  final SessionStorageService sessionStorage;

  const HistoryScreen({
    super.key,
    required this.sdRepository,
    required this.sessionStorage,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final SdCardImportService _importService = SdCardImportService();

  bool _importing = false;
  List<ImportedSession> _bleRecordings = [];
  bool _loadingBle = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadBleRecordings();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadBleRecordings() async {
    final sessions = await widget.sessionStorage.loadAll();
    if (mounted) {
      setState(() {
        _bleRecordings = sessions;
        _loadingBle = false;
      });
    }
  }

  Future<void> _importFile() async {
    setState(() => _importing = true);
    try {
      final session = await _importService.importFromFile();
      if (session == null) return;
      widget.sdRepository.add(session);
      if (!mounted) return;
      if (session.skippedPackets > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Importiert: ${session.samples.length} Samples'
            ' (${session.skippedPackets} fehlerhafte Pakete übersprungen)',
          ),
        ));
      }
      setState(() {});
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteBle(ImportedSession session) async {
    await widget.sessionStorage.delete(session.id);
    _loadBleRecordings();
  }

  @override
  Widget build(BuildContext context) {
    final sdSessions  = widget.sdRepository.getAll();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufnahmen'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.sd_card), text: 'SD-Import'),
            Tab(icon: Icon(Icons.bluetooth), text: 'BLE-Aufnahmen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Tab 0: SD imports ──────────────────────────────────────────
          sdSessions.isEmpty
              ? const Center(
                  child: Text(
                    'Noch keine SD-Importe.\nTippe auf + um eine Datei zu laden.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: sdSessions.length,
                  itemBuilder: (_, i) {
                    final s = sdSessions[i];
                    return _SessionTile(
                      session: s,
                      onTap: () => _push(s),
                      onDelete: () {
                        widget.sdRepository.remove(s.id);
                        setState(() {});
                      },
                    );
                  },
                ),

          // ── Tab 1: BLE recordings ──────────────────────────────────────
          _loadingBle
              ? const Center(child: CircularProgressIndicator())
              : _bleRecordings.isEmpty
                  ? const Center(
                      child: Text(
                        'Noch keine BLE-Aufnahmen.\nStarte eine Aufnahme im Live-Tab.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _bleRecordings.length,
                      itemBuilder: (_, i) {
                        final s = _bleRecordings[i];
                        return _SessionTile(
                          session: s,
                          onTap: () => _push(s),
                          onDelete: () => _deleteBle(s),
                        );
                      },
                    ),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _importing ? null : _importFile,
              icon: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: const Text('Datei importieren'),
            )
          : null,
    );
  }

  void _push(ImportedSession session) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ImportedSessionScreen(session: session)),
      );
}

// ── Shared session tile ───────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final ImportedSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
      '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        session.isFileBacked ? Icons.bluetooth : Icons.sd_card,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(session.sourceFile),
      subtitle: Text(
        '${_fmtDuration(session.duration)} · ${session.sampleCount} Samples'
        '\n${_fmtDate(session.importedAt)}',
      ),
      isThreeLine: true,
      onTap: onTap,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
        tooltip: 'Entfernen',
      ),
    );
  }
}
