import 'package:flutter/material.dart';
import '../l10n.dart';
import '../main.dart';

class InstallmentOperationsPage extends StatefulWidget {
  const InstallmentOperationsPage({super.key});
  @override
  State<InstallmentOperationsPage> createState() =>
      _InstallmentOperationsPageState();
}

class _InstallmentOperationsPageState
    extends State<InstallmentOperationsPage> {
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String _statusFilter = 'all';
  DateTimeRange? _dateRange;

  // Summary
  Map<String, _StatusSummary> _summary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var query = supabase.from('invoices').select('''
        id, invoice_number, status, total_amount, procedure_name,
        created_at, updated_at,
        service_providers!invoices_service_provider_id_fkey(name_en, name_ar, package),
        users_profile!invoices_user_id_fkey(full_name, phone, email)
      ''');

      if (_statusFilter != 'all') query = query.eq('status', _statusFilter);
      if (_dateRange != null) {
        query = query
            .gte('created_at', _dateRange!.start.toIso8601String())
            .lte('created_at', _dateRange!.end
                .add(const Duration(days: 1))
                .toIso8601String());
      }

      final data = await query.order('created_at', ascending: false).limit(500);
      final list = List<Map<String, dynamic>>.from(data);

      // Summary by status
      final summary = <String, _StatusSummary>{};
      for (final inv in list) {
        final s = (inv['status'] ?? 'unknown') as String;
        final amount = ((inv['total_amount'] ?? 0) as num).toDouble();
        summary.putIfAbsent(s, () => _StatusSummary(s));
        summary[s]!.count++;
        summary[s]!.total += amount;
      }

      if (mounted) {
        setState(() {
          _invoices = list;
          _summary = summary;
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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _load();
    }
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _fmtAmt(double v) {
    if (v >= 1000000) return '${S.egp} ${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${S.egp} ${(v / 1000).toStringAsFixed(1)}ألف';
    return '${S.egp} ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Expanded(
              child: Text(S.installmentOpsTitle,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('جاهز للتصدير: ${_invoices.length} فاتورة'))),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text(S.exportCsv),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(S.refresh),
            ),
          ]),
          const SizedBox(height: 16),

          // Filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(_dateRange == null
                    ? 'كل التواريخ'
                    : '${_fmtDate(_dateRange!.start)} – ${_fmtDate(_dateRange!.end)}'),
                onSelected: (_) => _pickDateRange(),
                avatar: const Icon(Icons.date_range, size: 16),
                selected: _dateRange != null,
              ),
              for (final s in ['all', 'sent', 'pending', 'active', 'paid', 'overdue'])
                ChoiceChip(
                  label: Text(_statusLabelAr(s)),
                  selected: _statusFilter == s,
                  onSelected: (_) {
                    setState(() => _statusFilter = s);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary cards
          if (_summary.isNotEmpty) ...[
            Text(S.pipelineSummary,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _summary.entries.map((e) {
                final color = _statusColor(e.key);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_arStatus(e.key),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('${e.value.count}',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      Text(_fmtAmt(e.value.total),
                          style:
                              TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Invoice table
          Text('${S.invoicePipeline} (${_invoices.length})',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
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
                      DataColumn(label: Text('رقم الفاتورة')),
                      DataColumn(label: Text('المريض')),
                      DataColumn(label: Text('الطبيب')),
                      DataColumn(label: Text('الإجراء')),
                      DataColumn(label: Text('المبلغ'), numeric: true),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('التاريخ')),
                    ],
                    rows: _invoices.take(100).map((inv) {
                      final user =
                          inv['users_profile'] as Map<String, dynamic>?;
                      final sp =
                          inv['service_providers'] as Map<String, dynamic>?;
                      final amount =
                          ((inv['total_amount'] ?? 0) as num).toDouble();
                      final dt = DateTime.tryParse(
                          inv['created_at'] as String? ?? '');
                      final status = (inv['status'] ?? '—') as String;
                      return DataRow(cells: [
                        DataCell(Text(
                            inv['invoice_number']?.toString() ??
                                '#${inv['id']}')),
                        DataCell(Text(user?['full_name'] ?? '—')),
                        DataCell(Text(
                            sp?['name_en'] ?? sp?['name_ar'] ?? '—')),
                        DataCell(Text(
                            (inv['procedure_name'] ?? '—') as String)),
                        DataCell(Text(
                            '${S.egp} ${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600))),
                        DataCell(_InvStatusBadge(status)),
                        DataCell(Text(
                            dt != null ? _fmtDate(dt) : '—')),
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

  Color _statusColor(String s) => switch (s.toLowerCase()) {
        'paid' => Colors.green,
        'active' => Colors.blue,
        'overdue' => Colors.red,
        'sent' => Colors.purple,
        'pending' => Colors.orange,
        _ => Colors.grey,
      };

  String _statusLabelAr(String s) => switch (s) {
        'all' => 'الكل',
        'sent' => 'مُرسل',
        'pending' => 'معلّق',
        'active' => 'نشط',
        'paid' => 'مدفوع',
        'overdue' => 'متأخر',
        _ => s,
      };
}

class _InvStatusBadge extends StatelessWidget {
  final String status;
  const _InvStatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'paid' => Colors.green,
      'active' => Colors.blue,
      'overdue' => Colors.red,
      'sent' => Colors.purple,
      'pending' => Colors.orange,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(_arStatus(status),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

String _arStatus(String s) => switch (s.toLowerCase()) {
  'paid' => 'مدفوع',
  'active' => 'نشط',
  'overdue' => 'متأخر',
  'sent' => 'مُرسل',
  'pending' => 'معلّق',
  _ => s,
};

class _StatusSummary {
  final String status;
  int count = 0;
  double total = 0;
  _StatusSummary(this.status);
}
