import 'package:flutter/material.dart';
import '../../data/storage/person_repository.dart';
import '../../data/storage/session_storage_service.dart';
import '../../domain/models/person.dart';
import '../../domain/models/imported_session.dart';
import '../history/imported_session_screen.dart';
import '../../l10n/l10n_ext.dart';
import 'person_form.dart';

class PersonsScreen extends StatefulWidget {
  final PersonRepository personRepository;
  final SessionStorageService sessionStorage;

  const PersonsScreen({
    super.key,
    required this.personRepository,
    required this.sessionStorage,
  });

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  List<Person> _persons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final persons = await widget.personRepository.getAll();
    if (mounted) setState(() { _persons = persons; _loading = false; });
  }

  Future<void> _openForm([Person? existing]) async {
    final result = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonFormScreen(
          repository: widget.personRepository,
          existing: existing,
        ),
      ),
    );
    if (result != null) _load();
  }

  Future<void> _delete(Person person) async {
    final l = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.personDeleteTitle),
        content: Text(l.personDeleteBody(person.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final sessions = await widget.sessionStorage.loadByPerson(person.id);
      for (final s in sessions) { await widget.sessionStorage.delete(s.id); }
      await widget.personRepository.delete(person.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.personsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _persons.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.personsEmpty,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _persons.length,
                  itemBuilder: (_, i) => _PersonTile(
                    person: _persons[i],
                    sessionStorage: widget.sessionStorage,
                    onEdit: () => _openForm(_persons[i]),
                    onDelete: () => _delete(_persons[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: context.l10n.newPerson,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// ── Person tile with expandable session list ──────────────────────────────────

class _PersonTile extends StatefulWidget {
  final Person person;
  final SessionStorageService sessionStorage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PersonTile({
    required this.person,
    required this.sessionStorage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PersonTile> createState() => _PersonTileState();
}

class _PersonTileState extends State<_PersonTile> {
  List<ImportedSession>? _sessions;
  bool _expanded = false;

  Future<void> _loadSessions() async {
    final sessions = await widget.sessionStorage.loadByPerson(widget.person.id);
    if (mounted) setState(() => _sessions = sessions);
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(child: Text(widget.person.name[0].toUpperCase())),
            title: Text(widget.person.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(context.l10n.personAge(widget.person.age) +
                (widget.person.notes.isNotEmpty ? ' · ${widget.person.notes}' : '')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: widget.onEdit),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                  color: Theme.of(context).colorScheme.error,
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() => _expanded = !_expanded);
                    if (_expanded && _sessions == null) _loadSessions();
                  },
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (_sessions == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_sessions!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(context.l10n.noRecordings,
                    style: const TextStyle(fontSize: 13)),
              )
            else
              ...(_sessions!.map((session) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.monitor_heart_outlined, size: 20),
                    title: Text(_fmtDate(session.importedAt),
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(_fmtDuration(session.duration),
                        style: const TextStyle(fontSize: 12)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ImportedSessionScreen(session: session)),
                    ),
                  ))),
          ],
        ],
      ),
    );
  }
}
