import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../main.dart';
import '../utils/doctor_account_helper.dart';
import 'add_edit_doctor_page.dart';

class DoctorsListPage extends StatefulWidget {
  const DoctorsListPage({super.key});

  @override
  State<DoctorsListPage> createState() => _DoctorsListPageState();
}

class _DoctorsListPageState extends State<DoctorsListPage> {
  List<Map<String, dynamic>> _doctors = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('service_providers')
          .select('''
              id, name, name_en, name_ar, phone, doctor_code, photo_url,
              package, top_doctor, created_at,
              categories(name, name_en),
              $doctorAccountsSelect
            ''')
          .order('created_at', ascending: false);
      if (mounted) setState(() => _doctors = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(S.confirmDelete),
        content: Text('هل تريد حذف "$name"؟\nسيتم حذف جميع مواقعه وساعات عمله أيضاً.'),
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
    if (confirmed != true) return;

    try {
      await supabase.from('service_providers').delete().eq('id', id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف "$name" بنجاح.')),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _openAddEdit([Map<String, dynamic>? doctor]) async {
    Map<String, dynamic>? fullDoctor;

    if (doctor != null) {
      // Fetch the complete record so the edit form has all fields populated
      try {
        fullDoctor = await supabase
            .from('service_providers')
            .select('''
              id, name, name_en, name_ar,
              description, description_en, description_ar,
              phone, doctor_code, photo_url, package, top_doctor,
              category_id, social_media,
              $doctorAccountsSelect,
              provider_locations(
                id, area_id,
                address_line, address_line_en, address_line_ar,
                latitude, longitude, booking_fee, is_active,
                provider_location_opening_hours(
                  id, day_of_week, from_time, to_time, is_closed
                )
              )
            ''')
            .eq('id', doctor['id'] as int)
            .single();
      } catch (e) {
        if (mounted) _showError('Failed to load doctor details: $e');
        return;
      }
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => AddEditDoctorPage(doctor: fullDoctor)),
    );
    if (result == true) _load();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _doctors;
    final q = _search.toLowerCase();
    return _doctors.where((d) {
      final name = ((d['name_en'] ?? d['name'] ?? '') as String).toLowerCase();
      final code = ((d['doctor_code'] ?? '') as String).toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  void _showCredentials(Map<String, dynamic> d) {
    final account = doctorAccountFrom(d);
    final email = account?['login_email'] as String?;
    final password = account?['login_password'] as String?;
    final authUserId = account?['auth_user_id'] as String?;
    final name = (d['name_en'] ?? d['name'] ?? 'طبيب') as String;

    if (email == null || email.isEmpty) {
      _showError(S.noAccountYet);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.vpn_key_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text(S.doctorCredentials)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(S.credentialsHint,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _CredentialRow(label: S.email, value: email),
            if (password != null && password.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CredentialRow(label: S.password, value: password),
            ],
            if (authUserId != null && authUserId.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CredentialRow(label: S.authUserId, value: authUserId),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(S.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.doctorsTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${_doctors.length} إجمالاً',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openAddEdit(),
                icon: const Icon(Icons.add),
                label: const Text(S.addDoctor),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Search ───────────────────────────────────────────────────────
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو كود الطبيب...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerLow,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 16),

          // ── Table ────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search,
                                size: 72, color: cs.outlineVariant),
                            const SizedBox(height: 12),
                            Text(
                              _search.isEmpty
                                  ? 'لا يوجد أطباء. اضغط "إضافة طبيب" للبدء.'
                                  : 'لا توجد نتائج لـ "$_search".',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
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
                                DataColumn(label: Text('الصورة')),
                                DataColumn(label: Text('الاسم (EN)')),
                                DataColumn(label: Text('الاسم (AR)')),
                                DataColumn(label: Text('الكود')),
                                DataColumn(label: Text('التصنيف')),
                                DataColumn(label: Text('الفئة')),
                                DataColumn(label: Text('مميز')),
                                DataColumn(label: Text('الإجراءات')),
                              ],
                              rows: _filtered
                                  .map((d) => _buildRow(d, cs))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> d, ColorScheme cs) {
    final nameEn = (d['name_en'] ?? d['name'] ?? '') as String;
    final nameAr = (d['name_ar'] ?? '') as String;
    final code = (d['doctor_code'] ?? '—') as String;
    final cat = d['categories'] as Map<String, dynamic>?;
    final catName = cat != null
        ? ((cat['name_en'] ?? cat['name'] ?? '') as String)
        : '—';
    final pkg = (d['package'] ?? 'silver') as String;
    final isTop = (d['top_doctor'] ?? false) as bool;
    final photoUrl = d['photo_url'] as String?;
    final hasAccount =
        (doctorAccountFrom(d)?['login_email'] as String?)?.isNotEmpty == true;

    return DataRow(cells: [
      // Photo
      DataCell(
        photoUrl != null && photoUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(photoUrl,
                    width: 40, height: 40, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarPlaceholder(cs)),
              )
            : _avatarPlaceholder(cs),
      ),

      DataCell(Text(nameEn, overflow: TextOverflow.ellipsis)),
      DataCell(Text(nameAr,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Arial'))),
      DataCell(
        code == '—'
            ? Text(code, style: TextStyle(color: cs.outline))
            : Chip(
                label: Text(code, style: const TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
      ),
      DataCell(Text(catName)),
      DataCell(_PackageBadge(pkg)),
      DataCell(
        Icon(
          isTop ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isTop ? Colors.amber : cs.outline,
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: S.showCredentials,
              icon: Icon(
                Icons.vpn_key_outlined,
                size: 20,
                color: hasAccount ? cs.primary : cs.outline,
              ),
              onPressed: () => _showCredentials(d),
            ),
            PopupMenuButton<String>(
          tooltip: S.actions,
          icon: const Icon(Icons.more_vert, size: 20),
          padding: EdgeInsets.zero,
          onSelected: (action) {
            if (action == 'credentials') {
              _showCredentials(d);
            } else if (action == 'edit') {
              _openAddEdit(d);
            } else if (action == 'delete') {
              _delete(d['id'] as int, nameEn);
            }
          },
          itemBuilder: (_) => [
            if (hasAccount)
              const PopupMenuItem(
                value: 'credentials',
                child: ListTile(
                  leading: Icon(Icons.vpn_key_outlined, size: 20),
                  title: Text(S.showCredentials),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined, size: 20),
                title: Text(S.edit),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, size: 20, color: cs.error),
                title: Text(S.delete, style: TextStyle(color: cs.error)),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    ]);
  }

  Widget _avatarPlaceholder(ColorScheme cs) => CircleAvatar(
        radius: 20,
        backgroundColor: cs.primaryContainer,
        child: Icon(Icons.person, color: cs.onPrimaryContainer),
      );
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                SelectableText(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            tooltip: S.copy,
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label — ${S.copied}')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PackageBadge extends StatelessWidget {
  final String package;
  const _PackageBadge(this.package);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (package) {
      'gold' => ('ذهبي', Colors.amber),
      'platinum' => ('بلاتيني', Colors.blueGrey),
      _ => ('فضي', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color.shade800)),
    );
  }
}
