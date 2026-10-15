import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/refund_watchdog_service.dart';
import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

/// Modal bottom sheet for "Never lose a refund again"
/// Tracks pending refunds, alerts after 5 days, computes RBI compensation,
/// and drafts formal bank/NPCI grievance complaints.
class RefundWatchdogSheet extends StatefulWidget {
  const RefundWatchdogSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => const RefundWatchdogSheet(),
    );
  }

  @override
  State<RefundWatchdogSheet> createState() => _RefundWatchdogSheetState();
}

class _RefundWatchdogSheetState extends State<RefundWatchdogSheet> {
  final TextEditingController _merchantCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _utrCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _smsPasteCtrl = TextEditingController();

  bool _showAddForm = false;

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _utrCtrl.dispose();
    _notesCtrl.dispose();
    _smsPasteCtrl.dispose();
    super.dispose();
  }

  void _scanSms() {
    final text = _smsPasteCtrl.text.trim();
    if (text.isEmpty) return;

    final result = RefundWatchdogService.analyzeText(text);
    if (result.isDetected) {
      setState(() {
        _merchantCtrl.text = result.merchant;
        if (result.amount > 0) _amountCtrl.text = result.amount.toStringAsFixed(0);
        if (result.utr != null) _utrCtrl.text = result.utr!;
        _showAddForm = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detected refund: ${result.merchant} ₹${result.amount.toStringAsFixed(0)}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No refund keywords found in pasted message.')),
      );
    }
  }

  void _saveRefund() async {
    final merchant = _merchantCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (merchant.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter merchant and valid amount.')),
      );
      return;
    }

    final s = context.read<V3State>();
    final ok = await s.addPendingRefund(
      merchant: merchant,
      amount: amount,
      utrRef: _utrCtrl.text.trim().isEmpty ? null : _utrCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (ok && mounted) {
      setState(() {
        _showAddForm = false;
        _merchantCtrl.clear();
        _amountCtrl.clear();
        _utrCtrl.clear();
        _notesCtrl.clear();
        _smsPasteCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund added to Watchdog tracking.')),
      );
    }
  }

  void _showComplaintModal(PendingRefundRow refund) {
    final letter = RefundWatchdogService.generateComplaintLetter(
      merchant: refund.merchant,
      amount: refund.amount,
      initiatedAt: refund.initiatedAt,
      utrNumber: refund.utrRef,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Nocturne.palette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Nocturne.palette.faint, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(PhRegular.warning, color: Nocturne.palette.expense, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'RBI Compensation Grievance Draft',
                    style: TextStyle(color: Nocturne.palette.text, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Nocturne.palette.subtle),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cites RBI Circular DPSS.CO.PD No.629 on failed UPI/card reversals beyond T+5 calendar days (₹100/day compensation).',
              style: TextStyle(color: Nocturne.palette.subtle, fontSize: 11.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Nocturne.palette.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Nocturne.palette.edge),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    letter,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: Nocturne.palette.text,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Nocturne.palette.text,
                      side: BorderSide(color: Nocturne.palette.faint),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: letter));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Complaint copied to clipboard.')),
                      );
                    },
                    icon: const Icon(PhRegular.copy, size: 16),
                    label: const Text('Copy Text'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Nocturne.palette.accent,
                      foregroundColor: Nocturne.palette.bg,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Share.share(
                        letter,
                        subject: 'Grievance: Unreversed refund of ₹${refund.amount.toStringAsFixed(0)}',
                      );
                    },
                    icon: const Icon(PhRegular.shareNetwork, size: 16),
                    label: const Text('Share Email', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final refunds = s.pendingRefunds;
    final delayed = refunds.where((r) => r.isDelayed && r.isPending).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Nocturne.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Nocturne.palette.faint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Nocturne.palette.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(PhRegular.arrowCounterClockwise, size: 20, color: Nocturne.palette.accentLight),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Never Lose A Refund Again',
                      style: TextStyle(color: Nocturne.palette.text, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Automatic 5-day SLA watch & RBI dispute drafter',
                      style: TextStyle(color: Nocturne.palette.subtle, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(_showAddForm ? Icons.close : PhRegular.plus, color: Nocturne.palette.accentLight),
                onPressed: () => setState(() => _showAddForm = !_showAddForm),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Delayed Alert Banner if any
          if (delayed.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Nocturne.palette.expense.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Nocturne.palette.expense, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(PhFill.warning, color: Nocturne.palette.expense, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🚨 ${delayed.length} Refund${delayed.length == 1 ? '' : 's'} Overdue (>5 Days)',
                          style: TextStyle(color: Nocturne.palette.expense, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'RBI mandates refund in T+5 days. Compensation of ₹100/day applies. Tap below to generate complaint letter.',
                          style: TextStyle(color: Nocturne.palette.neutral300, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Form or List
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showAddForm) ...[
                    _buildAddRefundForm(),
                    const SizedBox(height: 16),
                  ],

                  if (refunds.isEmpty && !_showAddForm) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(PhRegular.checkCircle, size: 40, color: Nocturne.palette.income),
                            const SizedBox(height: 12),
                            Text(
                              'No pending refunds',
                              style: TextStyle(color: Nocturne.palette.text, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Whenever a failed UPI debit occurs or a store initiates a refund, track it here. We will alert you if money is not back within 5 days.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Nocturne.palette.accent,
                                foregroundColor: Nocturne.palette.bg,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => setState(() => _showAddForm = true),
                              icon: const Icon(PhRegular.plus, size: 16),
                              label: const Text('Track a Refund / Failed Debit', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    for (final r in refunds) _buildRefundCard(r, s),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRefundForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Nocturne.palette.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Nocturne.palette.tintEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track New Refund / Failed UPI', style: TextStyle(color: Nocturne.palette.text, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),

          // Paste SMS box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Nocturne.palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Nocturne.palette.edge),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _smsPasteCtrl,
                    style: TextStyle(fontSize: 12, color: Nocturne.palette.text),
                    decoration: InputDecoration(
                      hintText: 'Paste refund SMS / failed debit text…',
                      hintStyle: TextStyle(fontSize: 11.5, color: Nocturne.palette.muted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _scanSms,
                  child: Text('Auto-Fill', style: TextStyle(color: Nocturne.palette.accentLight, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in ['Swiggy', 'Zomato', 'Amazon', 'Blinkit', 'IRCTC', 'Flipkart'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(p, style: TextStyle(fontSize: 11, color: Nocturne.palette.text)),
                      backgroundColor: Nocturne.palette.surface,
                      onPressed: () => setState(() => _merchantCtrl.text = p),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _merchantCtrl,
                  style: TextStyle(color: Nocturne.palette.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Merchant / Platform',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Nocturne.palette.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _utrCtrl,
            style: TextStyle(color: Nocturne.palette.text, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'UTR / Bank Reference (Optional)',
              labelStyle: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showAddForm = false),
                child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Nocturne.palette.accent,
                  foregroundColor: Nocturne.palette.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _saveRefund,
                child: const Text('Start Watching', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefundCard(PendingRefundRow r, V3State s) {
    final days = RefundWatchdogService.daysElapsed(r.initiatedAt);
    final isDelayed = r.isDelayed && r.isPending;
    final comp = RefundWatchdogService.compensationDue(r.initiatedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: r.isPending
            ? (isDelayed ? Nocturne.palette.expense.withValues(alpha: 0.10) : Nocturne.palette.surface)
            : Nocturne.palette.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDelayed ? Nocturne.palette.expense : Nocturne.palette.edge,
          width: isDelayed ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.merchant,
                  style: TextStyle(color: Nocturne.palette.text, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                V3Design.inr(r.amount),
                style: TextStyle(color: Nocturne.palette.text, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Text(
                'Initiated ${DateFormat('d MMM yyyy').format(r.initiatedAt)} ($days days ago)',
                style: TextStyle(color: Nocturne.palette.subtle, fontSize: 11),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: r.isPending
                      ? (isDelayed ? Nocturne.palette.expense : Nocturne.palette.warning)
                      : Nocturne.palette.income,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.isPending
                      ? (isDelayed ? 'Overdue ($days d)' : 'Watching ($days d)')
                      : 'Credited',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: r.isPending && isDelayed ? Colors.white : Nocturne.palette.bg,
                  ),
                ),
              ),
            ],
          ),

          if (r.utrRef != null) ...[
            const SizedBox(height: 4),
            Text('Ref/UTR: ${r.utrRef}', style: TextStyle(fontSize: 10.5, color: Nocturne.palette.muted)),
          ],

          if (isDelayed) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Nocturne.palette.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(PhRegular.bank, size: 14, color: Nocturne.palette.accentLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Exceeds RBI T+5 SLA. Accrued statutory compensation: ₹${comp.toStringAsFixed(0)} (₹100/day).',
                      style: TextStyle(fontSize: 11, color: Nocturne.palette.accentLight, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              if (r.isPending) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDelayed ? Nocturne.palette.expense : Nocturne.palette.surface,
                    foregroundColor: isDelayed ? Colors.white : Nocturne.palette.accentLight,
                    side: BorderSide(color: isDelayed ? Nocturne.palette.expense : Nocturne.palette.faint),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showComplaintModal(r),
                  icon: const Icon(PhRegular.warning, size: 13),
                  label: const Text('Draft Complaint', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => s.updateRefundStatus(r.id, 'received'),
                  child: Text('Mark Received', style: TextStyle(color: Nocturne.palette.income, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Text('Refund resolved & credited', style: TextStyle(color: Nocturne.palette.income, fontSize: 11)),
                const Spacer(),
                TextButton(
                  onPressed: () => s.updateRefundStatus(r.id, 'pending'),
                  child: Text('Re-open', style: TextStyle(color: Nocturne.palette.muted, fontSize: 11)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
