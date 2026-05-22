import '../../domain/models/imported_session.dart';

class ImportedSessionRepository {
  final List<ImportedSession> _sessions = [];

  void add(ImportedSession session) {
    _sessions.add(session);
  }

  List<ImportedSession> getAll() => List.unmodifiable(_sessions);

  ImportedSession? getById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  void remove(String id) {
    _sessions.removeWhere((s) => s.id == id);
  }
}
