import 'package:flutter/material.dart';
import '../../data/import/sd_card_import_service.dart';
import '../../data/storage/imported_session_repository.dart';
import '../../domain/models/imported_session.dart';
import 'imported_session_screen.dart';

class HistoryScreen extends StatefulWidget {
  final ImportedSessionRepository repository;

  const HistoryScreen({super.key, required this.repository});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final SdCardImportService _importService = SdCardImportService();
  bool _importing = false;

  Future<void> _importFile() async {
    setState(() => _importing = true);

    try {
      final session = await _importService.importFromFile();
      if (session == null) return;

      widget.repository.add(session);

      if (!mounted) return;

      if (session.skippedPackets > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importiert: ${session.samples.length} Samples'
              ' (${session.skippedPackets} fehlerhafte Pakete übersprungen)',
            ),
          ),
        );
      }

      setState(() {});
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.repository.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Importierte Aufnahmen')),
      body: sessions.isEmpty
          ? const Center(
              child: Text(
                'Noch keine Aufnahmen importiert.\nTippe auf + um eine SD-Karten-Datei zu laden.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _SessionTile(
                  session: session,
                  formatDuration: _formatDuration,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImportedSessionScreen(session: session),
                    ),
                  ),
                  onDelete: () {
                    widget.repository.remove(session.id);
                    setState(() {});
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _importFile,
        icon: _importing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
        label: const Text('Datei importieren'),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ImportedSession session;
  final String Function(Duration) formatDuration;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.formatDuration,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.monitor_heart),
      title: Text(session.sourceFile),
      subtitle: Text(
        '${formatDuration(session.duration)} · ${session.samples.length} Samples'
        '\n${_formatDate(session.importedAt)}',
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
        '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
