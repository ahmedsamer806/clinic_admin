import 'package:flutter/material.dart';
import '../l10n.dart';
import '../main.dart';

class PatientManagementPage extends StatefulWidget {
  const PatientManagementPage({super.key});
  @override
  State<PatientManagementPage> createState() =>
      _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;
  String _search = '';
  String _segmentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('users_profile')
          .select('id, full_name, email, phone, city, created_at, updated_at')
          .order('created_at', ascending: false)
          .limit(500);

      if (mounted) {
        setState(() {
          _patients = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  String _segment(Map<String, dynamic> p) {
    final created = DateTime.tryParse(p['created_at'] as String? ?? '');
    if (created == null) return 'غير معروف';
    final daysSince = DateTime.now().difference(created).inDays;
    if (daysSince < 7) return 'جديد';
    if (daysSince < 30) return 'نشط';
    if (daysSince < 90) return 'خامل (30-90 يوم)';
    return 'خامل (90+ يوم)';
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _patients;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) {
        final name = ((p['full_name'] ?? '') as String).toLowerCase();
        final email = ((p['email'] ?? '') as String).toLowerCase();
        final phone = ((p['phone'] ?? '') as String).toLowerCase();
        return name.contains(q) || email.contains(q) || phone.contains(q);
      }).toList();
    }
    if (_segmentFilter != 'all') {
      list = list.where((p) => _segment(p) == _segmentFilter).toList();
    }
    return list;
  }

  void _openProfile(Map<String, dynamic> patient) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PatientProfilePage(patient: patient),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    // Segment counts
    final segCounts = <String, int>{};
    for (final p in _patients) {
      final s = _segment(p);
      segCounts[s] = (segCounts[s] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.patientMgmtTitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${_patients.length} مريض إجمالاً',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(S.refresh),
            ),
          ]),
          const SizedBox(height: 16),

          // Segment summary chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _segmentChip('all', 'الكل', _patients.length, cs),
              for (final s in ['جديد', 'نشط', 'خامل (30-90 يوم)', 'خامل (90+ يوم)'])
                _segmentChip(s, s, segCounts[s] ?? 0, cs),
            ],
          ),
          const SizedBox(height: 16),

          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو البريد أو الهاتف...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerLow,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Table
          Text('${filtered.length} ${S.shown}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStatePropertyAll(cs.surfaceContainerLow),
                    columns: const [
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('البريد الإلكتروني')),
                      DataColumn(label: Text('الهاتف')),
                      DataColumn(label: Text('المدينة')),
                      DataColumn(label: Text('الشريحة')),
                      DataColumn(label: Text('تاريخ الانضمام')),
                      DataColumn(label: Text('الإجراءات')),
                    ],
                    rows: filtered.take(100).map((p) {
                      final created = DateTime.tryParse(
                          p['created_at'] as String? ?? '');
                      final seg = _segment(p);
                      return DataRow(cells: [
                        DataCell(Text((p['full_name'] ?? '—') as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500))),
                        DataCell(Text((p['email'] ?? '—') as String)),
                        DataCell(Text((p['phone'] ?? '—') as String)),
                        DataCell(Text((p['city'] ?? '—') as String)),
                        DataCell(_SegmentBadge(seg)),
                        DataCell(Text(created != null
                            ? '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}'
                            : '—')),
                        DataCell(IconButton(
                          tooltip: 'عرض الملف',
                          icon: Icon(Icons.open_in_new,
                              size: 18, color: cs.primary),
                          onPressed: () => _openProfile(p),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _segmentChip(
      String value, String label, int count, ColorScheme cs) {
    final selected = _segmentFilter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _segmentFilter = value),
      selectedColor: cs.primaryContainer,
    );
  }
}

// ── Patient Profile Page ─────────────────────────────────────────────────────
class _PatientProfilePage extends StatefulWidget {
  final Map<String, dynamic> patient;
  const _PatientProfilePage({required this.patient});
  @override
  State<_PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<_PatientProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _loans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final userId = widget.patient['id'];
    try {
      final results = await Future.wait([
        supabase
            .from('bookings')
            .select('id, status, created_at, service_providers(name_en)')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50),
        supabase
            .from('invoices')
            .select(
                'id, invoice_number, status, total_amount, procedure_name, created_at, service_providers(name_en)')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50),
        supabase
            .from('loan_requests')
            .select(
                'id, status, approved_amount, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(20),
      ]);
      if (mounted) {
        setState(() {
          _bookings = List<Map<String, dynamic>>.from(results[0]);
          _invoices = List<Map<String, dynamic>>.from(results[1]);
          _loans = List<Map<String, dynamic>>.from(results[2]);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.patient;

    return Scaffold(
      appBar: AppBar(
        title: Text(p['full_name'] ?? S.patientProfile),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الحجوزات'),
            Tab(text: 'الفواتير'),
            Tab(text: 'القروض'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info card
                Container(
                  width: double.infinity,
                  color: cs.surfaceContainerLow,
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 8,
                    children: [
                      _info('البريد الإلكتروني', p['email'] ?? '—'),
                      _info('الهاتف', p['phone'] ?? '—'),
                      _info('المدينة', p['city'] ?? '—'),
                      _info('تاريخ الانضمام',
                          _fmtDate(DateTime.tryParse(p['created_at'] ?? ''))),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _listView(_bookings, (b) => ListTile(
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: Text((b['service_providers']
                                    ?['name_en'] ??
                                '—') as String),
                            subtitle: Text('الحالة: ${b['status']}'),
                            trailing:
                                Text(_fmtDate(DateTime.tryParse(b['created_at'] ?? ''))),
                          )),
                      _listView(_invoices, (inv) => ListTile(
                            leading:
                                const Icon(Icons.receipt_long_outlined),
                            title: Text(
                                (inv['procedure_name'] ?? '—') as String),
                            subtitle: Text(
                                '${S.egp} ${inv['total_amount']} · ${inv['status']}'),
                            trailing: Text(_fmtDate(
                                DateTime.tryParse(inv['created_at'] ?? ''))),
                          )),
                      _listView(_loans, (loan) => ListTile(
                            leading: const Icon(
                                Icons.account_balance_wallet_outlined),
                            title: Text('قرض #${loan['id']}'),
                            subtitle: Text(
                                'الحالة: ${loan['status']} · ${loan['approved_amount'] != null ? '${S.egp} ${loan['approved_amount']}' : 'معلّق'}'),
                            trailing: Text(_fmtDate(
                                DateTime.tryParse(loan['created_at'] ?? ''))),
                          )),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );

  Widget _listView<T>(
          List<T> items, Widget Function(T) builder) =>
      items.isEmpty
          ? const Center(child: Text('لا توجد سجلات'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => builder(items[i]),
            );

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _SegmentBadge extends StatelessWidget {
  final String segment;
  const _SegmentBadge(this.segment);
  @override
  Widget build(BuildContext context) {
    final color = switch (segment) {
      'جديد' => Colors.green,
      'نشط' => Colors.blue,
      'خامل (30-90 يوم)' => Colors.orange,
      'خامل (90+ يوم)' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(segment,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
