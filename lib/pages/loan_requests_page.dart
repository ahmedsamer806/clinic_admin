// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n.dart';
import '../main.dart';

class LoanRequestsPage extends StatefulWidget {
  const LoanRequestsPage({super.key});
  @override
  State<LoanRequestsPage> createState() => _LoanRequestsPageState();
}

class _LoanRequestsPageState extends State<LoanRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _statusFilter = 'submitted';
  Map<String, dynamic>? _selected; // currently open detail

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final base = supabase.from('loan_requests').select('''
        id, user_id, name, phone, approved_amount, status,
        approved_by, created_at, updated_at,
        nid_front_url, nid_back_url,
        claim_report_photo_url, medical_report_url,
        additional_images,
        users_profile!loan_requests_user_id_fkey(
          id, full_name, phone, email, city, created_at
        )
      ''');

      final filtered = _statusFilter == 'all'
          ? base
          : base.eq('status', _statusFilter);

      final data = await filtered.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data);
          // refresh selected if open
          if (_selected != null) {
            final id = _selected!['id'];
            _selected =
                _requests.firstWhere((r) => r['id'] == id, orElse: () => _selected!);
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack(_friendlyError(e.toString()), isError: true);
      }
    }
  }

  // ── Direct approve (no RPC, avoids enum issues) ───────────────────────────
  // userId is a UUID string (Supabase auth UID), requestId is an int
  Future<void> _doApprove(
      int requestId, String userId, double amount) async {
    // 1. Update loan_requests status
    await supabase.from('loan_requests').update({
      'status': 'approved',
      'approved_amount': amount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    // 2. Get current wallet balance
    final wallets = await supabase
        .from('loan_wallets')
        .select('balance')
        .eq('user_id', userId)
        .limit(1);

    final double currentBalance =
        wallets.isNotEmpty ? ((wallets[0]['balance'] ?? 0) as num).toDouble() : 0;
    final double newBalance = currentBalance + amount;

    // 3. Upsert wallet record
    await supabase.from('loan_wallets').upsert({
      'user_id': userId,
      'balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    // 4. Insert wallet transaction log
    await supabase.from('loan_wallet_transactions').insert({
      'user_id': userId,
      'amount': amount,
      'transaction_type': 'loan_credit',
      'loan_request_id': requestId,
      'balance_after': newBalance,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ));
  }

  String _friendlyError(String msg) {
    if (msg.contains('42501') || msg.contains('permission denied')) {
      return 'رفض الإذن — قم بتشغيل supabase_full_permissions.sql في Supabase.';
    }
    if (msg.contains('22P02') || msg.contains('loan_status_t')) {
      return 'خطأ في القيم — تحقق من قيم loan_status_t في Supabase.';
    }
    if (msg.contains('not awaiting') || msg.contains('not pending')) {
      return 'تمت معالجة هذا الطلب مسبقاً.';
    }
    return 'خطأ: $msg';
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _userName(Map<String, dynamic> r) {
    final p = r['users_profile'] as Map<String, dynamic>?;
    return (p?['full_name'] ?? r['name'] ?? 'Unknown') as String;
  }

  bool _canApprove(String s) => s == 'submitted' || s == 'under_review';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showDetail = _selected != null;

    return Row(
      children: [
        // ── Left: list panel ────────────────────────────────────────────────
        Expanded(
          flex: showDetail ? 2 : 3,
          child: Padding(
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
                        Text(S.loanRequestsTitle,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text('${_requests.length} ${S.shown}',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: S.refresh,
                    icon: const Icon(Icons.refresh),
                    onPressed: _loading ? null : _load,
                  ),
                ]),
                const SizedBox(height: 14),

                // Status filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'submitted', label: Text('مقدّم')),
                      ButtonSegment(value: 'under_review', label: Text('قيد المراجعة')),
                      ButtonSegment(value: 'approved', label: Text('مقبول')),
                      ButtonSegment(value: 'rejected', label: Text('مرفوض')),
                      ButtonSegment(value: 'all', label: Text('الكل')),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (s) {
                      setState(() {
                        _statusFilter = s.first;
                        _selected = null;
                      });
                      _load();
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // List
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _requests.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined,
                                      size: 64, color: cs.outlineVariant),
                                  const SizedBox(height: 12),
                                  Text(S.noLoans,
                                      style: TextStyle(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _requests.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: cs.outlineVariant),
                              itemBuilder: (_, i) {
                                final r = _requests[i];
                                final isSelected = _selected?['id'] == r['id'];
                                return _LoanListTile(
                                  request: r,
                                  isSelected: isSelected,
                                  onTap: () => setState(() =>
                                      _selected = isSelected ? null : r),
                                  fmtDate: _fmtDate,
                                  userName: _userName(r),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),

        // ── Right: detail panel ─────────────────────────────────────────────
        if (showDetail) ...[
          VerticalDivider(width: 1, color: cs.outlineVariant),
          Expanded(
            flex: 3,
            child: _LoanDetailPanel(
              key: ValueKey(_selected!['id']),
              request: _selected!,
              fmtDate: _fmtDate,
              userName: _userName(_selected!),
              canApprove: _canApprove((_selected!['status'] ?? '') as String),
              onApproved: (amount) async {
                // user_id is a UUID string from Supabase Auth
                final userId = _selected!['user_id']?.toString();
                final requestId = _selected!['id'] as int;
                if (userId == null || userId.isEmpty) {
                  _showSnack('معرّف المستخدم مفقود', isError: true);
                  return;
                }
                try {
                  await _doApprove(requestId, userId, amount);
                  _showSnack('تمت الموافقة — تم إضافة ${S.egp} ${amount.toStringAsFixed(2)} للمحفظة.');
                  await _load();
                } catch (e) {
                  _showSnack(_friendlyError(e.toString()), isError: true);
                }
              },
              onRejected: () async {
                final requestId = _selected!['id'] as int;
                try {
                  await supabase.from('loan_requests').update({
                    'status': 'rejected',
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', requestId);
                  _showSnack('تم رفض طلب القرض.');
                  await _load();
                } catch (e) {
                  _showSnack(_friendlyError(e.toString()), isError: true);
                }
              },
              onClose: () => setState(() => _selected = null),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Loan list tile ────────────────────────────────────────────────────────────
class _LoanListTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isSelected;
  final VoidCallback onTap;
  final String Function(String?) fmtDate;
  final String userName;

  const _LoanListTile({
    required this.request,
    required this.isSelected,
    required this.onTap,
    required this.fmtDate,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (request['status'] ?? 'submitted') as String;
    final amount = request['approved_amount'];

    return Material(
      color: isSelected ? cs.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: _statusColor(status).withValues(alpha: 0.15),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    (request['users_profile'] as Map<String, dynamic>?)?['email'] ??
                        request['phone'] ??
                        '—',
                    style:
                        TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(fmtDate(request['created_at'] as String?),
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(status),
                if (amount != null) ...[
                  const SizedBox(height: 4),
                  Text('${S.egp} $amount',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
                ],
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'approved' => Colors.green,
        'rejected' => Colors.red,
        'under_review' => Colors.blue,
        _ => Colors.orange,
      };
}

// ── Loan Detail Panel ─────────────────────────────────────────────────────────
class _LoanDetailPanel extends StatefulWidget {
  final Map<String, dynamic> request;
  final String Function(String?) fmtDate;
  final String userName;
  final bool canApprove;
  final Future<void> Function(double amount) onApproved;
  final Future<void> Function() onRejected;
  final VoidCallback onClose;

  const _LoanDetailPanel({
    super.key,
    required this.request,
    required this.fmtDate,
    required this.userName,
    required this.canApprove,
    required this.onApproved,
    required this.onRejected,
    required this.onClose,
  });

  @override
  State<_LoanDetailPanel> createState() => _LoanDetailPanelState();
}

class _LoanDetailPanelState extends State<_LoanDetailPanel> {
  final _amountCtrl = TextEditingController();
  List<Map<String, dynamic>> _transactions = [];
  bool _loadingTx = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text =
        widget.request['approved_amount']?.toString() ?? '';
    _loadTransactions();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    try {
      final userId = widget.request['user_id'];
      if (userId == null) {
        if (mounted) setState(() => _loadingTx = false);
        return;
      }
      final data = await supabase
          .from('loan_wallet_transactions')
          .select('id, amount, transaction_type, balance_after, loan_request_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(data);
          _loadingTx = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTx = false);
    }
  }

  Future<void> _approve() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل مبلغاً صحيحاً أكبر من صفر')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.confirmApproval),
        content: Text(
            'إضافة ${S.egp} ${amount.toStringAsFixed(2)} لمحفظة ${widget.userName}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(S.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(S.approveLoan)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await widget.onApproved(amount);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.rejectLoan),
        content: Text('رفض طلب القرض المقدم من ${widget.userName}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(S.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(S.rejectLoan),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await widget.onRejected();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = widget.request;
    final profile = r['users_profile'] as Map<String, dynamic>?;
    final status = (r['status'] ?? 'submitted') as String;

    return Column(
      children: [
        // Detail header
        Container(
          color: cs.surfaceContainerLow,
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  _StatusBadge(status),
                ],
              ),
            ),
            IconButton(
                tooltip: S.close,
                icon: const Icon(Icons.close),
                onPressed: widget.onClose),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Request Details ─────────────────────────────────────────
                _section(S.loanDetails, [
                  _infoRow(S.requestId, '#${r['id']}'),
                  _infoRow(S.status, _statusAr(status)),
                  _infoRow(S.approvedAmount,
                      r['approved_amount'] != null
                          ? '${S.egp} ${r['approved_amount']}'
                          : '—'),
                  _infoRow(S.submitted, widget.fmtDate(r['created_at'] as String?)),
                  _infoRow(S.lastUpdated, widget.fmtDate(r['updated_at'] as String?)),
                  _infoRow(S.approvedBy,
                      r['approved_by'] != null ? '#${r['approved_by']}' : '—'),
                ]),
                const SizedBox(height: 20),

                // ── Applicant Profile ───────────────────────────────────────
                _section(S.applicantProfile, [
                  _infoRow(S.fullName, widget.userName),
                  _infoRow(S.phone, profile?['phone'] ?? r['phone'] ?? '—'),
                  _infoRow(S.email, profile?['email'] ?? '—'),
                  _infoRow(S.city, profile?['city'] ?? '—'),
                  _infoRow(S.memberSince,
                      widget.fmtDate(profile?['created_at'] as String?)),
                ]),
                const SizedBox(height: 20),

                // ── Documents & Images ──────────────────────────────────────
                _DocumentsSection(request: r),
                const SizedBox(height: 20),

                // ── Wallet Transaction History ───────────────────────────────
                Text(S.walletHistory,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                if (_loadingTx)
                  const Center(child: CircularProgressIndicator())
                else if (_transactions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(S.noTransactions,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  )
                else
                  ...(_transactions.map((tx) => _TransactionTile(tx: tx, fmtDate: widget.fmtDate))),

                // ── Approve / Reject Actions ─────────────────────────────────
                if (widget.canApprove) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(S.approveLoan,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'))
                          ],
                          decoration: const InputDecoration(
                            labelText: S.amountToCredit,
                            hintText: '0.00',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _processing ? null : _approve,
                              icon: _processing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(_processing
                                  ? S.processing
                                  : S.approveAndCredit),
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize:
                                      const Size.fromHeight(48)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _processing ? null : _reject,
                            icon: const Icon(Icons.cancel_outlined,
                                color: Colors.red),
                            label: const Text(S.rejectLoan,
                                style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.red),
                              minimumSize: const Size(120, 48),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ] else if (status == 'approved') ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 22),
                      const SizedBox(width: 10),
                      Text(
                          'تمت الموافقة — ${S.egp} ${r['approved_amount']} أُضيف للمحفظة.',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ] else if (status == 'rejected') ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.cancel, color: Colors.red, size: 22),
                      SizedBox(width: 10),
                      Text('تم رفض هذا الطلب.',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _statusAr(String s) => switch (s.toLowerCase()) {
        'approved' => 'مقبول',
        'rejected' => 'مرفوض',
        'under_review' => 'قيد المراجعة',
        'submitted' => 'مقدّم',
        _ => s,
      };

  Widget _section(String title, List<Widget> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: rows),
          ),
        ],
      );

  Widget _infoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final String Function(String?) fmtDate;
  const _TransactionTile({required this.tx, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = (tx['transaction_type'] ?? '') as String;
    final isCredit = type.contains('credit') || type.contains('deposit');
    final amount = ((tx['amount'] ?? 0) as num).toDouble();
    final balance = tx['balance_after'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isCredit ? Colors.green : Colors.red).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: (isCredit ? Colors.green : Colors.red)
                .withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(
          isCredit ? Icons.arrow_downward : Icons.arrow_upward,
          color: isCredit ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCredit ? Colors.green : Colors.red,
                      letterSpacing: 0.5)),
              Text(fmtDate(tx['created_at'] as String?),
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}${S.egp} ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green : Colors.red),
            ),
            if (balance != null)
                  Text(
                      'الرصيد: ${S.egp} ${((balance as num).toDouble()).toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ]),
    );
  }
}

// ── Supabase image loader ─────────────────────────────────────────────────────
// Strategy:
//   1. Parse bucket + path from the stored Supabase storage URL
//   2. Call supabase.storage.createSignedUrl() — JSON call, no CORS issue
//   3. Render the signed URL (or original URL) in an HTML <img> via HtmlElementView
//      → <img> tags bypass browser CORS for cross-origin images
class _SupabaseImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext) errorBuilder;

  const _SupabaseImage({
    required this.url,
    this.fit = BoxFit.cover,
    required this.errorBuilder,
  });

  @override
  State<_SupabaseImage> createState() => _SupabaseImageState();
}

final _registeredViewTypes = <String>{};

class _SupabaseImageState extends State<_SupabaseImage> {
  String? _resolvedUrl;
  bool _loading = true;
  bool _error = false;
  // ignore: unused_field
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _resolve();
  }


  // The mobile app stores loan KYC documents in this bucket
  static const _loanDocsBucket = 'loan-documents';

  Future<void> _resolve() async {
    try {
      // loan-documents is a private bucket — signed URL required
      final signed = await supabase.storage
          .from(_loanDocsBucket)
          .createSignedUrl(widget.url, 60 * 60); // 1 hour
      if (mounted) setState(() { _resolvedUrl = signed; _loading = false; });
    } catch (e) {
      // Likely means the RLS policy hasn't been applied yet.
      // Run supabase_loan_docs.sql in the Supabase SQL Editor to fix.
      _errorMsg = 'Permission denied — run supabase_loan_docs.sql in Supabase SQL Editor';
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error || _resolvedUrl == null) {
      return widget.errorBuilder(context);
    }

    final fitCss = switch (widget.fit) {
      BoxFit.cover => 'cover',
      BoxFit.contain => 'contain',
      BoxFit.fill => 'fill',
      _ => 'contain',
    };

    // Stable view-type key based on resolved URL
    final viewType = 'si_${_resolvedUrl.hashCode.abs()}';
    if (!_registeredViewTypes.contains(viewType)) {
      _registeredViewTypes.add(viewType);
      final src = _resolvedUrl!;
      ui_web.platformViewRegistry.registerViewFactory(viewType, (_) {
        final img = html.ImageElement()
          ..src = src
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = fitCss
          ..style.display = 'block';
        img.onError.listen((_) {
          debugPrint('   <img> onError for src: $src');
          if (mounted) {
            setState(() {
              _error = true;
              _errorMsg = 'src: $src';
            });
          }
        });
        return img;
      });
    }

    return HtmlElementView(viewType: viewType);
  }
}

// ── Documents & Images Section ────────────────────────────────────────────────
class _DocumentsSection extends StatelessWidget {
  final Map<String, dynamic> request;
  const _DocumentsSection({required this.request});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final docs = <_DocItem>[
      _DocItem(
        label: S.nidFront,
        url: request['nid_front_url'] as String?,
        icon: Icons.badge_outlined,
        color: Colors.indigo,
      ),
      _DocItem(
        label: S.nidBack,
        url: request['nid_back_url'] as String?,
        icon: Icons.badge,
        color: Colors.deepPurple,
      ),
      _DocItem(
        label: S.claimReport,
        url: request['claim_report_photo_url'] as String?,
        icon: Icons.description_outlined,
        color: Colors.teal,
      ),
      _DocItem(
        label: S.medicalReport,
        url: request['medical_report_url'] as String?,
        icon: Icons.medical_information_outlined,
        color: Colors.blue,
      ),
    ];

    // Extra images from additional_images array
    final extras = request['additional_images'];
    final List<String> extraUrls = extras == null
        ? []
        : (extras as List).map((e) => e.toString()).toList();

    final hasAnyDoc = docs.any((d) => d.url != null && d.url!.isNotEmpty) ||
        extraUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.folder_open_outlined, size: 18),
          const SizedBox(width: 6),
          const Text(S.docsAndImages,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        if (!hasAnyDoc)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(children: [
              Icon(Icons.image_not_supported_outlined,
                  color: cs.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Text(S.noDocuments,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final doc in docs)
                _DocCard(item: doc),
              for (int i = 0; i < extraUrls.length; i++)
                _DocCard(
                  item: _DocItem(
                    label: 'صورة ${i + 1}',
                    url: extraUrls[i],
                    icon: Icons.photo_outlined,
                    color: Colors.orange,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DocItem {
  final String label;
  final String? url;
  final IconData icon;
  final Color color;
  const _DocItem({
    required this.label,
    required this.url,
    required this.icon,
    required this.color,
  });

  bool get hasUrl => url != null && url!.isNotEmpty;
  bool get isImage => hasUrl && _looksLikeImage(url!);
  bool get isPdf => hasUrl && url!.toLowerCase().endsWith('.pdf');

  static bool _looksLikeImage(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }
}

class _DocCard extends StatelessWidget {
  final _DocItem item;
  const _DocCard({required this.item});

  void _open(BuildContext context) {
    if (!item.hasUrl) return;
    if (item.isImage) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => _ImageViewerDialog(label: item.label, url: item.url!),
      );
    } else {
      launchUrl(Uri.parse(item.url!), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasUrl = item.hasUrl;

    return Tooltip(
      message: hasUrl ? 'اضغط لعرض ${item.label}' : '${item.label} — ${S.notUploaded}',
      child: InkWell(
        onTap: hasUrl ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 148,
          decoration: BoxDecoration(
            color: hasUrl
                ? item.color.withValues(alpha: 0.07)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasUrl
                  ? item.color.withValues(alpha: 0.35)
                  : cs.outlineVariant,
              width: hasUrl ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: hasUrl && item.isImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            _SupabaseImage(
                              url: item.url!,
                              fit: BoxFit.cover,
                              errorBuilder: (_) => _placeholder(cs),
                            ),
                            // Hover overlay hint
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.zoom_in,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : hasUrl && item.isPdf
                          ? Container(
                              color: Colors.red.withValues(alpha: 0.08),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.picture_as_pdf,
                                      size: 40, color: Colors.red.shade400),
                                  const SizedBox(height: 4),
                                  Text('PDF',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade400,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          : _placeholder(cs),
                ),
              ),
              // Label
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Row(children: [
                  Icon(
                    hasUrl
                        ? (item.isPdf
                            ? Icons.picture_as_pdf
                            : item.isImage
                                ? Icons.image_outlined
                                : item.icon)
                        : item.icon,
                    size: 14,
                    color: hasUrl ? item.color : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasUrl ? item.color : cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasUrl)
                    Icon(Icons.open_in_new, size: 11, color: item.color),
                ]),
              ),
              if (!hasUrl)
                  Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(S.notUploaded,
                      style:
                          TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(item.icon, size: 36, color: cs.onSurfaceVariant),
        ),
      );
}

// ── Full-screen image viewer dialog ───────────────────────────────────────────
class _ImageViewerDialog extends StatelessWidget {
  final String label;
  final String url;
  const _ImageViewerDialog({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.88,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.image_outlined,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
              IconButton(
                tooltip: S.openInBrowser,
                icon: const Icon(Icons.open_in_new,
                    color: Colors.white70, size: 20),
                onPressed: () => launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close,
                    color: Colors.white70, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          // Image
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: _SupabaseImage(
                    url: url,
                    fit: BoxFit.contain,
                    errorBuilder: (_) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_outlined,
                            color: Colors.white30, size: 64),
                        const SizedBox(height: 12),
                        const Text(S.couldNotLoad,
                            style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SelectableText(
                            'URL: $url',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new,
                              color: Colors.white54),
                          label: const Text(S.openInBrowser,
                              style: TextStyle(color: Colors.white54)),
                          onPressed: () => launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status.toLowerCase()) {
      'approved' => ('مقبول', Colors.green),
      'rejected' => ('مرفوض', Colors.red),
      'under_review' => ('قيد المراجعة', Colors.blue),
      'submitted' => ('مقدّم', Colors.orange),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.shade700),
      ),
    );
  }
}
