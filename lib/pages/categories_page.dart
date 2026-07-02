import 'package:flutter/material.dart';

import '../l10n.dart';
import '../main.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await supabase
        .from('categories')
        .select('id, name, name_en, name_ar, created_at')
        .order('name_en');
    if (mounted) {
      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryDialog(item: item),
    );
    if (result == true) _load();
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(S.deleteCategory),
        content: Text(S.deleteCategoryMsg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(S.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await supabase.from('categories').delete().eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(S.categoriesTitle,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text(S.addCategory),
            ),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(S.noCategories,
                            style: TextStyle(color: cs.onSurfaceVariant)))
                    : Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStatePropertyAll(
                                  cs.surfaceContainerLow),
                              columns: const [
                                DataColumn(label: Text(S.idCol)),
                                DataColumn(label: Text(S.nameEnCol)),
                                DataColumn(label: Text(S.nameArCol)),
                                DataColumn(label: Text(S.nameBaseCol)),
                                DataColumn(label: Text(S.actions)),
                              ],
                              rows: _items.map((item) {
                                return DataRow(cells: [
                                  DataCell(Text('#${item['id']}')),
                                  DataCell(Text(item['name_en'] ?? '')),
                                  DataCell(Text(item['name_ar'] ?? '')),
                                  DataCell(Text(item['name'] ?? '')),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: S.edit,
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 20),
                                        onPressed: () => _openForm(item),
                                      ),
                                      IconButton(
                                        tooltip: S.delete,
                                        icon: Icon(Icons.delete_outline,
                                            size: 20, color: cs.error),
                                        onPressed: () => _delete(
                                            item['id'] as int,
                                            item['name_en'] ?? item['name'] ?? ''),
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  const _CategoryDialog({this.item});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _nameArCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?['name'] ?? '');
    _nameEnCtrl = TextEditingController(text: widget.item?['name_en'] ?? '');
    _nameArCtrl = TextEditingController(text: widget.item?['name_ar'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _nameArCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final isEdit = widget.item != null;
    final data = {
      'name': _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : _nameEnCtrl.text.trim(),
      'name_en': _nameEnCtrl.text.trim(),
      'name_ar': _nameArCtrl.text.trim(),
    };
    try {
      if (isEdit) {
        await supabase
            .from('categories')
            .update(data)
            .eq('id', widget.item!['id']);
      } else {
        await supabase.from('categories').insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? S.addCategory : S.editCategory),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameEnCtrl,
                decoration: const InputDecoration(labelText: S.nameEn),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? S.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameArCtrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: S.nameAr),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    const InputDecoration(labelText: S.nameBase),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(S.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text(S.save),
        ),
      ],
    );
  }
}
