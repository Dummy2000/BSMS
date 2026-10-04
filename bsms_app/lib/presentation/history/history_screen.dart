import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/export/csv_export_service.dart';
import '../../data/import/sd_card_import_service.dart';
import '../../data/storage/imported_session_repository.dart';
import '../../data/storage/session_storage_service.dart';
import '../../domain/models/imported_session.dart';
import '../../l10n/l10n_ext.dart';
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
  final CsvExportService _exportService = CsvExportService();

  bool _importing = false;
  List<ImportedSession> _bleRecordings = [];
  bool _loadingBle = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
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
          content: Text(context.l10n.importedSummary(
              session.samples.length, session.skippedPackets)),
        ));
      }
      setState(() {});
    } on FormatException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.importError),
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

  Future<void> _export(ImportedSession session, Rect shareOrigin) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(dialogContext.l10n.exportInProgress)),
            ],
          ),
        ),
      ),
    );

    File? file;
    Object? error;
    try {
      file = await _exportService.export(session);
    } catch (e) {
      error = e;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.exportFailed('$error')),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      return;
    }

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: session.sourceFile,
      sharePositionOrigin: shareOrigin,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sdSessions  = widget.sdRepository.getAll();

    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.historyTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.sd_card), text: l.tabSdImport),
            Tab(icon: const Icon(Icons.bluetooth), text: l.tabBleRecordings),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Tab 0: SD imports ──────────────────────────────────────────
          sdSessions.isEmpty
              ? Center(
                  child: Text(
                    l.sdEmpty,
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
                      onExport: (origin) => _export(s, origin),
                      onDelete: () {
                        widget.sdRepository.remove(s.id);
                        setState(() {});
                      },
                    );
                  },
                ),

          // ── Tab 1: BLE recordings ──────────────────────────────────────
          RefreshIndicator(
            onRefresh: _loadBleRecordings,
            child: _loadingBle
                ? const Center(child: CircularProgressIndicator())
                : _bleRecordings.isEmpty
                    ? ListView(
                        // Always scrollable so pull-to-refresh works on empty state.
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 200),
                          Center(
                            child: Text(
                              l.bleEmpty,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _bleRecordings.length,
                        itemBuilder: (_, i) {
                          final s = _bleRecordings[i];
                          return _SessionTile(
                            session: s,
                            onTap: () => _push(s),
                            onExport: (origin) => _export(s, origin),
                            onDelete: () => _deleteBle(s),
                          );
                        },
                      ),
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
              label: Text(l.importFile),
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

enum _TileAction { export, delete }

class _SessionTile extends StatelessWidget {
  final ImportedSession session;
  final VoidCallback onTap;
  final ValueChanged<Rect> onExport;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onExport,
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
        '${context.l10n.sessionSubtitle(_fmtDuration(session.duration), session.sampleCount)}'
        '\n${_fmtDate(session.importedAt)}',
      ),
      isThreeLine: true,
      onTap: onTap,
      trailing: Builder(
        builder: (menuContext) => PopupMenuButton<_TileAction>(
          icon: const Icon(Icons.more_vert),
          tooltip: context.l10n.tileOptionsTooltip,
          onSelected: (action) {
            switch (action) {
              case _TileAction.export:
                // iPad share sheets need an anchor rect.
                final box = menuContext.findRenderObject() as RenderBox;
                onExport(box.localToGlobal(Offset.zero) & box.size);
              case _TileAction.delete:
                onDelete();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _TileAction.export,
              child: ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(context.l10n.exportCsv),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _TileAction.delete,
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.l10n.deleteAction),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
