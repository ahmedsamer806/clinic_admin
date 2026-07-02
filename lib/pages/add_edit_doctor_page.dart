import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n.dart';
import '../main.dart';
import '../services/doctor_account_service.dart';
import '../utils/doctor_account_helper.dart';

/// Full add / edit form for a single doctor (service_provider).
/// Handles:
///   • Basic doctor info  (service_providers row)
///   • Multiple locations (provider_locations rows)
///   • 7-day opening hours per location (provider_location_opening_hours rows)
class AddEditDoctorPage extends StatefulWidget {
  final Map<String, dynamic>? doctor;
  const AddEditDoctorPage({super.key, this.doctor});

  @override
  State<AddEditDoctorPage> createState() => _AddEditDoctorPageState();
}

class _AddEditDoctorPageState extends State<AddEditDoctorPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Basic info controllers ───────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _nameArCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _descriptionEnCtrl;
  late final TextEditingController _descriptionArCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _doctorCodeCtrl;
  late final TextEditingController _photoUrlCtrl;
  late final TextEditingController _facebookCtrl;
  late final TextEditingController _instagramCtrl;
  late final TextEditingController _twitterCtrl;

  String _package = 'silver';
  bool _topDoctor = false;
  int? _categoryId;

  // ── Multiple locations ───────────────────────────────────────────────────
  final List<_LocationEntry> _locations = [];
  final Set<int> _deletedLocationIds = {};

  // ── Dropdowns ───────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _areas = [];

  bool _saving = false;
  bool _loadingDropdowns = true;

  static const _dayNames = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء',
    'الخميس', 'الجمعة', 'السبت',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    final sm = d?['social_media'] as Map<String, dynamic>? ?? {};

    _nameCtrl = TextEditingController(text: d?['name'] ?? '');
    _nameEnCtrl = TextEditingController(text: d?['name_en'] ?? '');
    _nameArCtrl = TextEditingController(text: d?['name_ar'] ?? '');
    _descriptionCtrl = TextEditingController(text: d?['description'] ?? '');
    _descriptionEnCtrl = TextEditingController(text: d?['description_en'] ?? '');
    _descriptionArCtrl = TextEditingController(text: d?['description_ar'] ?? '');
    _phoneCtrl = TextEditingController(text: d?['phone'] ?? '');
    _emailCtrl = TextEditingController(
        text: doctorAccountFrom(d)?['login_email'] ?? '');
    _passwordCtrl = TextEditingController();
    _doctorCodeCtrl = TextEditingController(text: d?['doctor_code'] ?? '');
    _photoUrlCtrl = TextEditingController(text: d?['photo_url'] ?? '');
    _facebookCtrl = TextEditingController(text: sm['facebook'] ?? '');
    _instagramCtrl = TextEditingController(text: sm['instagram'] ?? '');
    _twitterCtrl = TextEditingController(text: sm['twitter'] ?? '');

    _package = (d?['package'] ?? 'silver') as String;
    _topDoctor = (d?['top_doctor'] ?? false) as bool;
    _categoryId = d?['category_id'] as int?;

    // Build locations list from existing data
    final rawLocs = (d?['provider_locations'] as List?) ?? [];
    for (final rawLoc in rawLocs) {
      final loc = rawLoc as Map<String, dynamic>;
      final rawHours = (loc['provider_location_opening_hours'] as List?) ?? [];
      final hoursMap = {
        for (final h in rawHours)
          (h as Map<String, dynamic>)['day_of_week'] as int: h
      };
      final hours = List.generate(7, (i) {
        final h = hoursMap[i];
        return _HourEntry(
          from: h != null ? _parseTime(h['from_time'] as String) : const TimeOfDay(hour: 9, minute: 0),
          to: h != null ? _parseTime(h['to_time'] as String) : const TimeOfDay(hour: 17, minute: 0),
          closed: h != null ? (h['is_closed'] ?? false) as bool : false,
          existingId: h?['id'] as int?,
        );
      });
      _locations.add(_LocationEntry(
        existingId: loc['id'] as int?,
        address: loc['address_line'] ?? '',
        addressEn: loc['address_line_en'] ?? '',
        addressAr: loc['address_line_ar'] ?? '',
        lat: loc['latitude']?.toString() ?? '',
        lng: loc['longitude']?.toString() ?? '',
        bookingFee: loc['booking_fee']?.toString() ?? '',
        isActive: (loc['is_active'] ?? true) as bool,
        areaId: loc['area_id'] as int?,
        hours: hours,
      ));
    }
    if (_locations.isEmpty) _locations.add(_LocationEntry());

    _loadDropdowns();
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _loadDropdowns() async {
    try {
      final res = await Future.wait([
        supabase.from('categories').select('id, name, name_en').order('name_en'),
        supabase.from('areas').select('id, name, name_en').order('name_en'),
      ]);
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(res[0]);
          _areas = List<Map<String, dynamic>>.from(res[1]);
          _loadingDropdowns = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDropdowns = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _nameEnCtrl, _nameArCtrl,
      _descriptionCtrl, _descriptionEnCtrl, _descriptionArCtrl,
      _phoneCtrl, _emailCtrl, _passwordCtrl, _doctorCodeCtrl, _photoUrlCtrl,
      _facebookCtrl, _instagramCtrl, _twitterCtrl,
    ]) {
      c.dispose();
    }
    for (final loc in _locations) loc.dispose();
    super.dispose();
  }

  String _generatePassword() {
    const chars =
        'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final isEdit = widget.doctor != null;
      final doctorId = widget.doctor?['id'] as int?;

      final sm = <String, String>{};
      if (_facebookCtrl.text.trim().isNotEmpty) sm['facebook'] = _facebookCtrl.text.trim();
      if (_instagramCtrl.text.trim().isNotEmpty) sm['instagram'] = _instagramCtrl.text.trim();
      if (_twitterCtrl.text.trim().isNotEmpty) sm['twitter'] = _twitterCtrl.text.trim();

      // 1️⃣  Upsert service_provider
      final providerData = {
        'name': _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : _nameEnCtrl.text.trim(),
        'name_en': _nameEnCtrl.text.trim(),
        'name_ar': _nameArCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'description_en': _descriptionEnCtrl.text.trim(),
        'description_ar': _descriptionArCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'doctor_code': _doctorCodeCtrl.text.trim().isNotEmpty
            ? _doctorCodeCtrl.text.trim()
            : null,
        'photo_url': _photoUrlCtrl.text.trim().isNotEmpty
            ? _photoUrlCtrl.text.trim()
            : null,
        'package': _package,
        'top_doctor': _topDoctor,
        'category_id': _categoryId,
        'social_media': sm.isNotEmpty ? sm : null,
      };

      int providerId;
      if (isEdit && doctorId != null) {
        await supabase.from('service_providers').update(providerData).eq('id', doctorId);
        providerId = doctorId;
      } else {
        final loginEmail = _emailCtrl.text.trim();
        final loginPassword = _passwordCtrl.text.trim();
        if (loginEmail.isEmpty || !loginEmail.contains('@')) {
          throw Exception('أدخل بريد تسجيل دخول صحيحاً للطبيب');
        }
        if (loginPassword.length < 6) {
          throw Exception('كلمة مرور الحساب يجب أن تكون 6 أحرف على الأقل');
        }

        // Insert doctor profile first, then auth account + credentials row
        final res = await supabase
            .from('service_providers')
            .insert(providerData)
            .select('id')
            .single();
        providerId = res['id'] as int;

        try {
          final authUserId = await DoctorAccountService.createAuthUser(
            email: loginEmail,
            password: loginPassword,
            fullName: _nameEnCtrl.text.trim().isNotEmpty
                ? _nameEnCtrl.text.trim()
                : _nameCtrl.text.trim(),
          );

          await supabase.from('doctor_accounts').insert({
            'service_provider_id': providerId,
            'auth_user_id': authUserId,
            'login_email': loginEmail,
            'login_password': loginPassword,
          });
        } catch (e) {
          await supabase.from('service_providers').delete().eq('id', providerId);
          rethrow;
        }
      }

      // 2️⃣  Delete removed locations
      for (final id in _deletedLocationIds) {
        await supabase
            .from('provider_location_opening_hours')
            .delete()
            .eq('location_id', id);
        await supabase.from('provider_locations').delete().eq('id', id);
      }

      // 3️⃣  Upsert each location + its opening hours
      for (final loc in _locations) {
        final hasAddress = loc.addressEnCtrl.text.trim().isNotEmpty ||
            loc.addressCtrl.text.trim().isNotEmpty;
        if (!hasAddress) continue;

        final locData = {
          'service_provider_id': providerId,
          'area_id': loc.areaId,
          'address_line': loc.addressCtrl.text.trim().isNotEmpty
              ? loc.addressCtrl.text.trim()
              : loc.addressEnCtrl.text.trim(),
          'address_line_en': loc.addressEnCtrl.text.trim(),
          'address_line_ar': loc.addressArCtrl.text.trim(),
          'latitude': double.tryParse(loc.latCtrl.text.trim()),
          'longitude': double.tryParse(loc.lngCtrl.text.trim()),
          'booking_fee': double.tryParse(loc.bookingFeeCtrl.text.trim()),
          'is_active': loc.isActive,
        };

        int locationId;
        if (loc.existingId != null) {
          await supabase
              .from('provider_locations')
              .update(locData)
              .eq('id', loc.existingId!);
          locationId = loc.existingId!;
        } else {
          final res = await supabase
              .from('provider_locations')
              .insert(locData)
              .select('id')
              .single();
          locationId = res['id'] as int;
        }

        // 4️⃣  Upsert opening hours for this location
        for (int i = 0; i < 7; i++) {
          final h = loc.hours[i];
          final hoursData = {
            'location_id': locationId,
            'day_of_week': i,
            'from_time': _fmtTime(h.from),
            'to_time': _fmtTime(h.to),
            'is_closed': h.closed,
          };
          if (h.existingId != null) {
            await supabase
                .from('provider_location_opening_hours')
                .update(hoursData)
                .eq('id', h.existingId!);
          } else {
            await supabase
                .from('provider_location_opening_hours')
                .upsert(hoursData, onConflict: 'location_id,day_of_week');
          }
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final friendly = e is AuthException
            ? DoctorAccountService.friendlyAuthError(e)
            : msg.contains('أدخل بريد') || msg.contains('كلمة مرور الحساب')
                ? msg.replaceFirst('Exception: ', '')
                : msg.contains('doctor_code')
                    ? 'كود الطبيب مستخدم مسبقاً. الرجاء اختيار كود آخر.'
                    : msg.contains('phone')
                        ? 'رقم الهاتف مسجل لطبيب آخر.'
                        : msg.contains('login_email') ||
                                msg.contains('duplicate key')
                            ? 'البريد الإلكتروني مستخدم مسبقاً.'
                            : msg.contains('doctor_accounts') ||
                                    (msg.contains('column') &&
                                        msg.contains('login_'))
                                ? 'شغّل supabase_doctor_accounts.sql في Supabase لإنشاء جدول doctor_accounts.'
                                : 'خطأ: ${msg.replaceFirst('Exception: ', '')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendly),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(int locIndex, int dayIndex, bool isFrom) async {
    final h = _locations[locIndex].hours[dayIndex];
    final current = isFrom ? h.from : h.to;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final loc = _locations[locIndex];
        if (isFrom) {
          loc.hours[dayIndex] = loc.hours[dayIndex].copyWith(from: picked);
        } else {
          loc.hours[dayIndex] = loc.hours[dayIndex].copyWith(to: picked);
        }
      });
    }
  }

  void _addLocation() {
    setState(() => _locations.add(_LocationEntry()));
  }

  void _removeLocation(int index) {
    setState(() {
      final loc = _locations.removeAt(index);
      if (loc.existingId != null) _deletedLocationIds.add(loc.existingId!);
      loc.dispose();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.doctor != null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? S.editDoctor : S.addDoctor),
        actions: [
          if (_saving) ...[
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            const SizedBox(width: 16),
          ] else
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(isEdit ? 'تحديث' : S.save),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loadingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionCard(
                          context,
                          icon: Icons.person_outline,
                          title: S.basicInfo,
                          children: _buildBasicFields(cs),
                        ),
                        if (widget.doctor == null) ...[
                          const SizedBox(height: 20),
                          _sectionCard(
                            context,
                            icon: Icons.vpn_key_outlined,
                            title: S.doctorLoginAccount,
                            children: _buildAccountFields(cs),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _sectionCard(
                          context,
                          icon: Icons.share_outlined,
                          title: S.socialMedia,
                          children: _buildSocialFields(),
                        ),
                        const SizedBox(height: 20),

                        // ── Locations ──────────────────────────────────────
                        for (int i = 0; i < _locations.length; i++) ...[
                          _buildLocationCard(i, _locations[i], cs),
                          const SizedBox(height: 16),
                        ],

                        // Add Location button
                        OutlinedButton.icon(
                          onPressed: _addLocation,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text(S.addLocation),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),

                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            isEdit ? 'تحديث بيانات الطبيب' : 'حفظ بيانات الطبيب',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Location card ─────────────────────────────────────────────────────────
  Widget _buildLocationCard(int index, _LocationEntry loc, ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.primary.withOpacity(0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'الموقع ${index + 1}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_locations.length > 1)
                  TextButton.icon(
                    onPressed: () => _removeLocation(index),
                    icon: Icon(Icons.delete_outline, color: cs.error, size: 18),
                    label: Text(S.removeLocation, style: TextStyle(color: cs.error)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Address fields
            _row([
              _field(loc.addressEnCtrl, 'العنوان (إنجليزي) *', required: true),
              _field(loc.addressArCtrl, 'العنوان (عربي)',
                  textDirection: TextDirection.rtl),
            ]),
            const SizedBox(height: 12),
            _field(loc.addressCtrl, 'العنوان الأساسي (احتياطي)'),
            const SizedBox(height: 16),

            // Area + Booking fee
            _row([
              _buildDropdown(
                label: 'المنطقة',
                value: loc.areaId,
                items: _areas,
                onChanged: (v) => setState(() => loc.areaId = v as int?),
              ),
              _field(
                loc.bookingFeeCtrl,
                'رسوم الحجز',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                prefixIcon: Icons.attach_money_outlined,
              ),
            ]),
            const SizedBox(height: 16),

            // Lat / Lng
            _row([
              _field(loc.latCtrl, 'خط العرض',
                  hint: '24.7136',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
                  ]),
              _field(loc.lngCtrl, 'خط الطول',
                  hint: '46.6753',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
                  ]),
            ]),
            const SizedBox(height: 12),

            // Active toggle
            Row(children: [
              Switch(
                value: loc.isActive,
                onChanged: (v) => setState(() => loc.isActive = v),
              ),
              const SizedBox(width: 8),
              const Text('نشط / يقبل الحجوزات'),
            ]),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Opening hours header
            Row(children: [
              Icon(Icons.access_time_outlined, color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Text('ساعات العمل',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),

            // Hours table header
            Row(children: const [
              Expanded(flex: 3, child: Text('اليوم', style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('من', style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('إلى', style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(flex: 2, child: Text('مغلق', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
            const Divider(height: 12),

            for (int d = 0; d < 7; d++) _buildHourRow(index, d, loc.hours[d], cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHourRow(int locIndex, int dayIndex, _HourEntry h, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              _dayNames[dayIndex],
              style: TextStyle(
                color: h.closed ? cs.outline : null,
                decoration: h.closed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _timeTile(h.from, h.closed,
                onTap: () => _pickTime(locIndex, dayIndex, true)),
          ),
          Expanded(
            flex: 3,
            child: _timeTile(h.to, h.closed,
                onTap: () => _pickTime(locIndex, dayIndex, false)),
          ),
          Expanded(
            flex: 2,
            child: Switch(
              value: h.closed,
              onChanged: (v) => setState(() {
                _locations[locIndex].hours[dayIndex] =
                    _locations[locIndex].hours[dayIndex].copyWith(closed: v);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(TimeOfDay t, bool disabled, {required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: disabled
              ? cs.surfaceContainerLow
              : cs.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: disabled ? cs.outlineVariant : cs.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 14,
                color: disabled ? cs.outline : cs.primary),
            const SizedBox(width: 4),
            Text(
              t.format(context),
              style: TextStyle(
                  color: disabled ? cs.outline : cs.onSurface, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section card ──────────────────────────────────────────────────────────
  Widget _sectionCard(BuildContext ctx,
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    final cs = Theme.of(ctx).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  // ── Basic fields ──────────────────────────────────────────────────────────
  List<Widget> _buildBasicFields(ColorScheme cs) {
    return [
      _row([
        _field(_nameEnCtrl, 'الاسم (إنجليزي) *', required: true),
        _field(_nameArCtrl, 'الاسم (عربي)', textDirection: TextDirection.rtl),
      ]),
      const SizedBox(height: 16),
      _row([
        _field(_nameCtrl, 'اسم العرض (احتياطي)'),
        _field(_phoneCtrl, 'رقم الهاتف', keyboardType: TextInputType.phone),
      ]),
      const SizedBox(height: 16),
      _row([
        _field(_doctorCodeCtrl, 'كود الطبيب', hint: 'يستخدم لطلبات الدفع'),
        _field(_photoUrlCtrl, 'رابط الصورة', hint: 'https://…'),
      ]),
      const SizedBox(height: 16),
      _row([
        _buildDropdown(
          label: 'التصنيف',
          value: _categoryId,
          items: _categories,
          onChanged: (v) => setState(() => _categoryId = v as int?),
        ),
        _buildDropdown(
          label: 'الفئة',
          value: _package,
          items: const [
            {'id': 'silver', 'label': 'فضي'},
            {'id': 'gold', 'label': 'ذهبي'},
            {'id': 'platinum', 'label': 'بلاتيني'},
          ],
          isString: true,
          onChanged: (v) => setState(() => _package = v as String),
        ),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Switch(
          value: _topDoctor,
          onChanged: (v) => setState(() => _topDoctor = v),
        ),
        const SizedBox(width: 8),
        const Text('طبيب مميز / بارز'),
        const SizedBox(width: 4),
        Tooltip(
          message: 'الأطباء المميزون يظهرون في قسم المميزين بالصفحة الرئيسية.',
          child: Icon(Icons.info_outline, size: 16, color: cs.outline),
        ),
      ]),
      const SizedBox(height: 16),
      _field(_descriptionEnCtrl, 'الوصف (إنجليزي)', maxLines: 3),
      const SizedBox(height: 12),
      _field(_descriptionArCtrl, 'الوصف (عربي)',
          maxLines: 3, textDirection: TextDirection.rtl),
      const SizedBox(height: 12),
      _field(_descriptionCtrl, 'الوصف الأساسي (احتياطي)', maxLines: 3),
      if (_photoUrlCtrl.text.trim().isNotEmpty) ...[
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            _photoUrlCtrl.text.trim(),
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 80,
              color: cs.surfaceContainerLow,
              child: Center(
                child: Text('رابط الصورة غير صالح',
                    style: TextStyle(color: cs.outline)),
              ),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildAccountFields(ColorScheme cs) {
    return [
      _row([
        _field(
          _emailCtrl,
          S.loginEmail,
          required: true,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return S.required;
            if (!v.contains('@')) return S.invalidEmail;
            return null;
          },
        ),
        _field(
          _passwordCtrl,
          S.loginPassword,
          required: true,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
          validator: (v) =>
              (v == null || v.length < 6) ? S.passwordMin : null,
        ),
      ]),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => setState(() => _passwordCtrl.text = _generatePassword()),
          icon: const Icon(Icons.autorenew, size: 18),
          label: const Text(S.generatePassword),
        ),
      ),
      Text(
        S.credentialsHint,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
    ];
  }

  // ── Social media fields ───────────────────────────────────────────────────
  List<Widget> _buildSocialFields() {
    return [
      _row([
        _field(_facebookCtrl, 'رابط فيسبوك',
            hint: 'https://facebook.com/…', prefixIcon: Icons.facebook),
        _field(_instagramCtrl, 'رابط انستجرام',
            hint: 'https://instagram.com/…',
            prefixIcon: Icons.camera_alt_outlined),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: _field(_twitterCtrl, 'رابط X / تويتر',
            hint: 'https://x.com/…', prefixIcon: Icons.alternate_email),
      ),
    ];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _row(List<Widget> children) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
            .toList()
          ..removeLast(),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextDirection textDirection = TextDirection.ltr,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textDirection: textDirection,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        ),
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty) ? S.required : null
                : null),
        onChanged: label.contains('Photo') || label.contains('صورة')
            ? (_) => setState(() {})
            : null,
      );

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List items,
    required void Function(dynamic) onChanged,
    bool isString = false,
  }) {
    return DropdownButtonFormField<dynamic>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('— None —',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ),
        ...items.map((item) {
          final id = item['id'];
          final lbl = isString
              ? item['label']
              : ((item['name_en'] ?? item['name'] ?? '') as String);
          return DropdownMenuItem(value: id, child: Text(lbl));
        }),
      ],
      onChanged: onChanged,
    );
  }
}

// ── Location entry (holds controllers + hours for one location) ──────────────
class _LocationEntry {
  final TextEditingController addressCtrl;
  final TextEditingController addressEnCtrl;
  final TextEditingController addressArCtrl;
  final TextEditingController latCtrl;
  final TextEditingController lngCtrl;
  final TextEditingController bookingFeeCtrl;
  bool isActive;
  int? areaId;
  final int? existingId;
  List<_HourEntry> hours;

  _LocationEntry({
    String address = '',
    String addressEn = '',
    String addressAr = '',
    String lat = '',
    String lng = '',
    String bookingFee = '',
    this.isActive = true,
    this.areaId,
    this.existingId,
    List<_HourEntry>? hours,
  })  : addressCtrl = TextEditingController(text: address),
        addressEnCtrl = TextEditingController(text: addressEn),
        addressArCtrl = TextEditingController(text: addressAr),
        latCtrl = TextEditingController(text: lat),
        lngCtrl = TextEditingController(text: lng),
        bookingFeeCtrl = TextEditingController(text: bookingFee),
        hours = hours ??
            List.generate(
              7,
              (_) => const _HourEntry(
                from: TimeOfDay(hour: 9, minute: 0),
                to: TimeOfDay(hour: 17, minute: 0),
                closed: false,
              ),
            );

  void dispose() {
    addressCtrl.dispose();
    addressEnCtrl.dispose();
    addressArCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    bookingFeeCtrl.dispose();
  }
}

// ── Data class for one day's hours ──────────────────────────────────────────
class _HourEntry {
  final TimeOfDay from;
  final TimeOfDay to;
  final bool closed;
  final int? existingId;

  const _HourEntry({
    required this.from,
    required this.to,
    required this.closed,
    this.existingId,
  });

  _HourEntry copyWith({TimeOfDay? from, TimeOfDay? to, bool? closed}) =>
      _HourEntry(
        from: from ?? this.from,
        to: to ?? this.to,
        closed: closed ?? this.closed,
        existingId: existingId,
      );
}
