import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/person.dart';
import '../../data/storage/person_repository.dart';
import '../../l10n/l10n_ext.dart';

class PersonFormScreen extends StatefulWidget {
  final PersonRepository repository;
  final Person? existing; // null = create new

  const PersonFormScreen({super.key, required this.repository, this.existing});

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.existing?.name  ?? '');
    _ageCtrl   = TextEditingController(text: widget.existing?.age.toString() ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final person = Person(
      id:    widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name:  _nameCtrl.text.trim(),
      age:   int.parse(_ageCtrl.text.trim()),
      notes: _notesCtrl.text.trim(),
    );

    if (widget.existing == null) {
      await widget.repository.insert(person);
    } else {
      await widget.repository.update(person);
    }

    if (mounted) Navigator.pop(context, person);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? l.newPerson : l.editPerson)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l.fieldName,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.nameRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageCtrl,
              decoration: InputDecoration(
                labelText: l.fieldAge,
                border: const OutlineInputBorder(),
                suffixText: l.yearsSuffix,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 120) return l.validAge;
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: l.fieldNotes,
                border: const OutlineInputBorder(),
                hintText: l.notesHint,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isNew ? l.create : l.save),
            ),
          ],
        ),
      ),
    );
  }
}
