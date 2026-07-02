import 'package:flutter/material.dart';
import '../l10n.dart';
import '../main.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _targetSegment = 'all';
  bool _sending = false;

  // Categories management
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCats = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await supabase
          .from('installment_procedure_categories')
          .select('id, name_en, name_ar, is_active')
          .order('name_en');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
          _loadingCats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _toggleCategory(int id, bool isActive) async {
    try {
      await supabase
          .from('installment_procedure_categories')
          .update({'is_active': !isActive}).eq('id', id);
      _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _sendNotification() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('العنوان والنص مطلوبان')));
      return;
    }
    setState(() => _sending = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulated
    if (mounted) {
      setState(() => _sending = false);
      _titleCtrl.clear();
      _bodyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تم إرسال الإشعار للشريحة: ${_targetSegment == 'all' ? 'كل المستخدمين' : _targetSegment}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.notificationsTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Notification composer
          _sectionCard(
            cs,
            icon: Icons.campaign_outlined,
            title: S.sendPush,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _targetSegment,
                  decoration: const InputDecoration(
                      labelText: S.targetAudience),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text(S.allUsers)),
                    DropdownMenuItem(
                        value: 'new', child: Text(S.newUsers)),
                    DropdownMenuItem(
                        value: 'active', child: Text(S.activeUsers)),
                    DropdownMenuItem(
                        value: 'dormant_30',
                        child: Text(S.dormant30Users)),
                    DropdownMenuItem(
                        value: 'dormant_90',
                        child: Text(S.dormant90Users)),
                  ],
                  onChanged: (v) =>
                      setState(() => _targetSegment = v ?? 'all'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: S.notifTitle,
                    hintText: S.notifTitleHint,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: S.notifBody,
                    hintText: S.notifBodyHint,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _sendNotification,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined),
                    label: Text(
                        _sending ? S.sending : S.sendNotification),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Procedure categories management
          _sectionCard(
            cs,
            icon: Icons.category_outlined,
            title: S.procedureCategories,
            child: _loadingCats
                ? const Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                    ? const Text('لا توجد تصنيفات')
                    : Column(
                        children: _categories
                            .map((cat) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title:
                                      Text(cat['name_en'] as String? ?? ''),
                                  subtitle: Text(
                                      cat['name_ar'] as String? ?? ''),
                                  trailing: Switch(
                                    value:
                                        (cat['is_active'] ?? false) as bool,
                                    onChanged: (_) => _toggleCategory(
                                        cat['id'] as int,
                                        (cat['is_active'] ?? false) as bool),
                                  ),
                                ))
                            .toList(),
                      ),
          ),
          const SizedBox(height: 20),

          // Export reports card
          _sectionCard(
            cs,
            icon: Icons.picture_as_pdf_outlined,
            title: S.reportsExports,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _exportBtn(
                    S.monthlyReport, Icons.bar_chart_outlined, Colors.blue),
                _exportBtn(
                    S.bookingsCsv, Icons.calendar_today_outlined, Colors.green),
                _exportBtn(
                    S.invoicesCsv, Icons.receipt_long_outlined, Colors.purple),
                _exportBtn(
                    S.patientListCsv, Icons.people_outline, Colors.teal),
                _exportBtn(S.doctorListCsv,
                    Icons.medical_services_outlined, Colors.indigo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportBtn(String label, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.generating} $label'))),
      icon: Icon(icon, size: 18, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4))),
    );
  }

  Widget _sectionCard(ColorScheme cs,
      {required IconData icon,
      required String title,
      required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: cs.primary, size: 22),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
