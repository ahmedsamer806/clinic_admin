import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../l10n.dart';
import '../main.dart';
import '../widgets/metric_card.dart';

class DashboardPage extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const DashboardPage({super.key, this.onNavigate});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _timer;
  DateTime _lastRefresh = DateTime.now();
  bool _loading = true;

  int _bookingsToday = 0;
  int _invoicesMtdCount = 0;
  double _invoicesMtdEgp = 0;
  int _registrationsToday = 0;
  int _totalPatients = 0;
  int _activeDoctors = 0;
  double _revenueMtd = 0;
  int _pendingLoans = 0;

  List<FlSpot> _bookingsTrend = [];
  List<_PieSlice> _revenueBreakdown = [];
  List<_BarData> _registrationsByDay = [];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day).toIso8601String();
      final monthStart = DateTime.utc(now.year, now.month, 1).toIso8601String();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30)).toIso8601String();
      final sevenDaysAgo = now.subtract(const Duration(days: 7)).toIso8601String();

      final results = await Future.wait([
        supabase.from('bookings').select('id').gte('created_at', todayStart),
        supabase.from('invoices').select('id, total_amount').gte('created_at', monthStart),
        supabase.from('users_profile').select('id').gte('created_at', todayStart),
        supabase.from('users_profile').select('id'),
        supabase.from('service_providers').select('id').eq('is_active', true),
        supabase.from('loan_requests').select('id').eq('status', 'submitted'),
        supabase.from('bookings').select('created_at').gte('created_at', thirtyDaysAgo),
        supabase.from('invoices').select('created_at, total_amount').gte('created_at', thirtyDaysAgo),
        supabase.from('users_profile').select('created_at').gte('created_at', sevenDaysAgo),
      ]);

      final bookingsToday = (results[0] as List).length;
      final invoicesList = results[1] as List;
      final invoicesMtd = invoicesList.length;
      final invoicesEgp = invoicesList.fold<double>(
          0, (s, e) => s + ((e['total_amount'] ?? 0) as num).toDouble());
      final regsToday = (results[2] as List).length;
      final totalPatients = (results[3] as List).length;
      final activeDoctors = (results[4] as List).length;
      final pendingLoans = (results[5] as List).length;

      // Bookings trend
      final bookings30 = results[6] as List;
      final trendMap = <int, int>{};
      for (final b in bookings30) {
        final dt = DateTime.tryParse(b['created_at'] as String? ?? '');
        if (dt == null) continue;
        final d = now.difference(dt.toUtc()).inDays.clamp(0, 29);
        trendMap[d] = (trendMap[d] ?? 0) + 1;
      }
      final trend = List.generate(30,
          (i) => FlSpot((29 - i).toDouble(), (trendMap[i] ?? 0).toDouble()));

      // Revenue
      final inv30 = results[7] as List;
      double revTotal = inv30.fold<double>(
          0, (s, e) => s + ((e['total_amount'] ?? 0) as num).toDouble());
      final pie = [
        _PieSlice(S.installmentFees, revTotal * 0.6, Colors.blue),
        _PieSlice(S.bookingCommission, revTotal * 0.3, Colors.green),
        _PieSlice(S.cardSales, revTotal * 0.1, Colors.orange),
      ];

      // Registrations last 7 days
      final regs7 = results[8] as List;
      final regMap = <int, int>{};
      for (final r in regs7) {
        final dt = DateTime.tryParse(r['created_at'] as String? ?? '');
        if (dt == null) continue;
        final d = now.difference(dt.toUtc()).inDays.clamp(0, 6);
        regMap[d] = (regMap[d] ?? 0) + 1;
      }
      final bars = List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        final label = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'][day.weekday % 7];
        return _BarData(label, (regMap[6 - i] ?? 0).toDouble());
      });

      if (mounted) {
        setState(() {
          _bookingsToday = bookingsToday;
          _invoicesMtdCount = invoicesMtd;
          _invoicesMtdEgp = invoicesEgp;
          _registrationsToday = regsToday;
          _totalPatients = totalPatients;
          _activeDoctors = activeDoctors;
          _revenueMtd = revTotal;
          _pendingLoans = pendingLoans;
          _bookingsTrend = trend;
          _revenueBreakdown = pie;
          _registrationsByDay = bars;
          _lastRefresh = DateTime.now();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = _lastRefresh;
    final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(S.dashboardTitle,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text('${S.lastRefreshed}: $timeStr · تحديث تلقائي كل 60 ثانية',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ]),
            ),
            FilledButton.tonalIcon(
              onPressed: _load,
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
              label: const Text(S.refresh),
            ),
          ]),
          const SizedBox(height: 24),

          // 8 Metric Cards
          LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 3 : 2;
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            final cards = [
              (
                S.bookingsToday, '$_bookingsToday', null,
                Icons.calendar_today_outlined, Colors.blue, 2
              ),
              (
                S.invoicesMtd, '$_invoicesMtdCount',
                '${S.egp} ${_fmt(_invoicesMtdEgp)}',
                Icons.receipt_long_outlined, Colors.purple, 3
              ),
              (
                S.registrationsToday, '$_registrationsToday', null,
                Icons.person_add_outlined, Colors.green, 4
              ),
              (
                S.totalPatients, _fmt(_totalPatients.toDouble()), null,
                Icons.people_outline, Colors.teal, 4
              ),
              (
                S.activeDoctors, '$_activeDoctors', null,
                Icons.medical_services_outlined, Colors.indigo, 1
              ),
              (
                S.revenueMtd, '${S.egp} ${_fmt(_revenueMtd)}', null,
                Icons.monetization_on_outlined, Colors.amber.shade700, 3
              ),
              (
                S.pendingLoans, '$_pendingLoans', null,
                Icons.account_balance_wallet_outlined, Colors.orange, 5
              ),
              (
                S.procedureCategories, 'إدارة',
                'اضغط للعرض', Icons.category_outlined,
                Colors.pink, 6
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards.map((card) {
                final (title, value, subtitle, icon, color, navIdx) = card;
                return SizedBox(
                  width: w,
                  child: MetricCard(
                    title: title,
                    value: value,
                    subtitle: subtitle,
                    icon: icon,
                    color: color,
                    loading: _loading && value != 'Manage',
                    onTap: () => widget.onNavigate?.call(navIdx),
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 28),

          // Charts: trend + pie
          LayoutBuilder(builder: (ctx, c) {
            final wide = c.maxWidth > 900;
            return Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: wide ? c.maxWidth * 0.6 - 8 : double.infinity,
                  child: _ChartCard(
                    title: 'الحجوزات – آخر 30 يوم',
                    child: _bookingsTrend.isEmpty
                        ? _empty(cs)
                        : Padding(
                            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 4),
                            child: LineChart(LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                    color: cs.outlineVariant.withValues(alpha: 0.4),
                                    strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 5,
                                    getTitlesWidget: (v, _) {
                                      final d = (29 - v).toInt();
                                      if (d % 5 != 0) return const SizedBox();
                                      return Text('${d}d',
                                          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant));
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _bookingsTrend,
                                  isCurved: true,
                                  color: Colors.blue,
                                  barWidth: 2.5,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.blue.withValues(alpha: 0.08)),
                                ),
                              ],
                            )),
                          ),
                  ),
                ),
                SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                SizedBox(
                  width: wide ? c.maxWidth * 0.4 - 8 : double.infinity,
                  child: _ChartCard(
                    title: 'توزيع الإيرادات (30 يوم)',
                    child: _revenueBreakdown.every((s) => s.value == 0)
                        ? _empty(cs)
                        : Row(children: [
                            Expanded(
                              child: PieChart(PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 32,
                                sections: _revenueBreakdown
                                    .map((s) => PieChartSectionData(
                                          value: s.value,
                                          color: s.color,
                                          radius: 50,
                                          title: '',
                                        ))
                                    .toList(),
                              )),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _revenueBreakdown
                                  .map((s) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(children: [
                                          Container(
                                              width: 10, height: 10,
                                              decoration: BoxDecoration(
                                                  color: s.color, shape: BoxShape.circle)),
                                          const SizedBox(width: 6),
                                          Text(s.label, style: const TextStyle(fontSize: 11)),
                                        ]),
                                      ))
                                  .toList(),
                            ),
                          ]),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Registrations bar
          _ChartCard(
            title: 'التسجيلات الجديدة – آخر 7 أيام',
            child: _registrationsByDay.isEmpty
                ? _empty(cs)
                : Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8, bottom: 4),
                    child: BarChart(BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i >= _registrationsByDay.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(_registrationsByDay[i].label,
                                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                              color: cs.outlineVariant.withValues(alpha: 0.4),
                              strokeWidth: 1)),
                      barGroups: List.generate(
                        _registrationsByDay.length,
                        (i) => BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: _registrationsByDay[i].value,
                            color: Colors.green,
                            width: 22,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ]),
                      ),
                    )),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty(ColorScheme cs) =>
      Center(child: Text('لا توجد بيانات بعد', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)));
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SizedBox(height: 180, child: child),
          ],
        ),
      ),
    );
  }
}

class _PieSlice {
  final String label;
  final double value;
  final Color color;
  const _PieSlice(this.label, this.value, this.color);
}

class _BarData {
  final String label;
  final double value;
  const _BarData(this.label, this.value);
}
