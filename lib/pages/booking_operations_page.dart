import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../l10n.dart';
import '../main.dart';

class BookingOperationsPage extends StatefulWidget {
  const BookingOperationsPage({super.key});
  @override
  State<BookingOperationsPage> createState() => _BookingOperationsPageState();
}

class _BookingOperationsPageState extends State<BookingOperationsPage> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  DateTimeRange? _dateRange;
  String _statusFilter = 'all';

  // Charts data
  Map<String, int> _statusCounts = {};
  List<_DoctorLeaderboard> _topDoctors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var query = supabase.from('bookings').select('''
        id, status, user_id, service_provider_id, provider_location_id,
        notes, created_at, updated_at,
        service_providers!bookings_service_provider_id_fkey(
          id, name_en, name_ar, package, categories(name_en)
        ),
        users_profile!bookings_user_id_fkey(full_name, phone, email)
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

      // Count by status
      final counts = <String, int>{};
      for (final b in list) {
        final s = (b['status'] ?? 'unknown') as String;
        counts[s] = (counts[s] ?? 0) + 1;
      }

      // Top doctors
      final doctorMap = <String, _DoctorLeaderboard>{};
      for (final b in list) {
        final sp = b['service_providers'] as Map<String, dynamic>?;
        if (sp == null) continue;
        final id = sp['id'].toString();
        final name = (sp['name_en'] ?? sp['name_ar'] ?? 'Unknown') as String;
        final tier = (sp['package'] ?? 'silver') as String;
        doctorMap.putIfAbsent(id, () => _DoctorLeaderboard(id, name, tier));
        doctorMap[id]!.bookings++;
      }
      final topDocs = doctorMap.values.toList()
        ..sort((a, b) => b.bookings.compareTo(a.bookings));

      if (mounted) {
        setState(() {
          _bookings = list;
          _statusCounts = counts;
          _topDoctors = topDocs.take(10).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showErr(e.toString());
      }
    }
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
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

  void _exportCsv() {
    final header = 'ID,Status,User,Doctor,Date\n';
    final rows = _bookings.map((b) {
      final user = b['users_profile'] as Map<String, dynamic>?;
      final sp = b['service_providers'] as Map<String, dynamic>?;
      return '${b['id']},${b['status']},${user?['full_name'] ?? ''},${sp?['name_en'] ?? ''},${b['created_at']}';
    }).join('\n');
    // Web: trigger download via JS or show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('جاهز للتصدير (${_bookings.length} سجل)')),
    );
    debugPrint(header + rows);
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
              child: Text(S.bookingOpsTitle,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            OutlinedButton.icon(
              onPressed: _exportCsv,
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
              for (final s in ['all', 'confirmed', 'completed', 'cancelled', 'no_show'])
                ChoiceChip(
                  label: Text(_statusLabel(s)),
                  selected: _statusFilter == s,
                  onSelected: (_) {
                    setState(() => _statusFilter = s);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Status breakdown cards
          if (_statusCounts.isNotEmpty) ...[
            _sectionTitle('توزيع الحالات'),
            const SizedBox(height: 12),
            _StatusBreakdownRow(_statusCounts, _bookings.length),
            const SizedBox(height: 20),
          ],

          // Charts row
          LayoutBuilder(builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 860;
            return Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status pie
                SizedBox(
                  width: wide ? 260 : double.infinity,
                  child: _chartCard(
                    'Status Breakdown',
                    height: 220,
                    child: _statusCounts.isEmpty
                        ? const Center(child: Text('No data'))
                        : PieChart(PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: _statusCounts.entries.map((e) {
                              final color = _statusColor(e.key, cs);
                              return PieChartSectionData(
                                value: e.value.toDouble(),
                                color: color,
                                radius: 50,
                                title: '',
                              );
                            }).toList(),
                          )),
                  ),
                ),
                SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                // Top doctors
                Expanded(
                  flex: wide ? 1 : 0,
                  child: _chartCard(
                    'أفضل الأطباء بالحجوزات',
                    height: 220,
                    child: _topDoctors.isEmpty
                        ? const Center(child: Text('لا توجد بيانات'))
                        : Padding(
                            padding: const EdgeInsets.only(right: 8, top: 4),
                            child: BarChart(BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, m) {
                                      final i = v.toInt();
                                      if (i >= _topDoctors.length) return const SizedBox();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _topDoctors[i].name.split(' ').first,
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: cs.onSurfaceVariant),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              barGroups: List.generate(
                                _topDoctors.length,
                                (i) => BarChartGroupData(x: i, barRods: [
                                  BarChartRodData(
                                    toY: _topDoctors[i].bookings.toDouble(),
                                    color: Colors.indigo,
                                    width: 14,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3)),
                                  ),
                                ]),
                              ),
                            )),
                          ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 20),

          // Bookings table
          _sectionTitle('سجلات الحجوزات (${_bookings.length})'),
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
                      DataColumn(label: Text('الرقم')),
                      DataColumn(label: Text('المريض')),
                      DataColumn(label: Text('الطبيب')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('التاريخ')),
                    ],
                    rows: _bookings.take(100).map((b) {
                      final user = b['users_profile'] as Map<String, dynamic>?;
                      final sp = b['service_providers'] as Map<String, dynamic>?;
                      final status = (b['status'] ?? '—') as String;
                      return DataRow(cells: [
                        DataCell(Text('#${b['id']}')),
                        DataCell(Text(user?['full_name'] ?? '—')),
                        DataCell(Text(sp?['name_en'] ?? sp?['name_ar'] ?? '—')),
                        DataCell(_StatusChip(status)),
                        DataCell(Text(_fmtDate(
                            DateTime.tryParse(b['created_at'] as String? ?? '') ??
                                DateTime.now()))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),

          // Top Doctors Leaderboard
          const SizedBox(height: 20),
          _sectionTitle('لوحة شرف الأطباء'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(cs.surfaceContainerLow),
                columns: const [
                  DataColumn(label: Text('الترتيب')),
                  DataColumn(label: Text('الطبيب')),
                  DataColumn(label: Text('الفئة')),
                  DataColumn(label: Text('الحجوزات'), numeric: true),
                ],
                rows: List.generate(_topDoctors.length, (i) {
                  final d = _topDoctors[i];
                  return DataRow(cells: [
                    DataCell(Text('#${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(d.name)),
                    DataCell(_TierBadge(d.tier)),
                    DataCell(Text('${d.bookings}',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  Widget _chartCard(String title,
          {required Widget child, double height = 200}) =>
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(height: height, child: child),
            ],
          ),
        ),
      );

  Color _statusColor(String s, ColorScheme cs) => switch (s) {
        'confirmed' => Colors.blue,
        'completed' => Colors.green,
        'cancelled' => Colors.red,
        'no_show' => Colors.orange,
        _ => Colors.grey,
      };

  String _statusLabel(String s) => switch (s) {
        'all' => 'الكل',
        'confirmed' => 'مؤكد',
        'completed' => 'مكتمل',
        'cancelled' => 'ملغى',
        'no_show' => 'لم يحضر',
        _ => s,
      };

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'confirmed' => (Colors.blue, 'مؤكد'),
      'completed' => (Colors.green, 'مكتمل'),
      'cancelled' => (Colors.red, 'ملغى'),
      'no_show' => (Colors.orange, 'لم يحضر'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge(this.tier);
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (tier) {
      'gold' => (Colors.amber, 'ذهبي'),
      'platinum' => (Colors.blueGrey, 'بلاتيني'),
      _ => (Colors.grey, 'فضي'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color.shade700)),
    );
  }
}

class _StatusBreakdownRow extends StatelessWidget {
  final Map<String, int> counts;
  final int total;
  const _StatusBreakdownRow(this.counts, this.total);

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: entries.map((e) {
        final pct = total == 0 ? 0.0 : e.value / total * 100;
        final color = switch (e.key) {
          'confirmed' => Colors.blue,
          'completed' => Colors.green,
          'cancelled' => Colors.red,
          'no_show' => Colors.orange,
          _ => Colors.grey,
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.key.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color.withValues(alpha: 0.8),
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text('${e.value}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text('${pct.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DoctorLeaderboard {
  final String id;
  final String name;
  final String tier;
  int bookings = 0;
  _DoctorLeaderboard(this.id, this.name, this.tier);
}
