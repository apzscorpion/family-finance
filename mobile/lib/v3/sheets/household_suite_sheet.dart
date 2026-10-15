import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/upi_service.dart';
import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

/// Modal bottom sheet for Indian Household essentials:
/// 1. Daily Deliveries Diary (Milk, newspaper, water cans skip calendar & billing)
/// 2. Helper & Domestic Staff Ledger (Maid, driver, cook advances & salary)
/// 3. Refunds Watchdog (Pending UPI & merchant refunds with automated grievance drafting)
class HouseholdSuiteSheet extends StatefulWidget {
  final int initialTab;
  const HouseholdSuiteSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => HouseholdSuiteSheet(initialTab: initialTab),
    );
  }

  @override
  State<HouseholdSuiteSheet> createState() => _HouseholdSuiteSheetState();
}

class _HouseholdSuiteSheetState extends State<HouseholdSuiteSheet> {
  late int _tab;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DIALOGS & ACTIONS
  // ──────────────────────────────────────────────────────────────────────────

  void _showAddSubscriptionDialog() {
    final s = context.read<V3State>();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final vendorNameCtrl = TextEditingController();
    final vendorPhoneCtrl = TextEditingController();
    String itemType = 'milk';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Nocturne.palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Add Daily Delivery', style: TextStyle(color: Nocturne.palette.text, fontSize: 17, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: itemType,
                  dropdownColor: Nocturne.palette.surface,
                  decoration: InputDecoration(
                    labelText: 'Delivery Type',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  ),
                  items: [
                    DropdownMenuItem(value: 'milk', child: Text('Milk (Packet/Litre)', style: TextStyle(color: Nocturne.palette.text))),
                    DropdownMenuItem(value: 'newspaper', child: Text('Newspaper', style: TextStyle(color: Nocturne.palette.text))),
                    DropdownMenuItem(value: 'water', child: Text('Water Can (20L)', style: TextStyle(color: Nocturne.palette.text))),
                    DropdownMenuItem(value: 'other', child: Text('Other Daily Item', style: TextStyle(color: Nocturne.palette.text))),
                  ],
                  onChanged: (v) => setDialogState(() => itemType = v ?? 'milk'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Item Name (e.g. Nandini Blue 500ml)',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Unit Price (₹ per day / delivery)',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vendorNameCtrl,
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Vendor / Delivery Person (Optional)',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vendorPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Vendor Phone / UPI (Optional)',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Nocturne.palette.accent,
                foregroundColor: Nocturne.palette.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                if (name.isEmpty || price <= 0) return;

                final ok = await s.addDeliverySubscription(
                  name: name,
                  itemType: itemType,
                  unitPrice: price,
                  vendorName: vendorNameCtrl.text.trim().isNotEmpty ? vendorNameCtrl.text.trim() : null,
                  vendorPhone: vendorPhoneCtrl.text.trim().isNotEmpty ? vendorPhoneCtrl.text.trim() : null,
                );
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStaffDialog() {
    final s = context.read<V3State>();
    final nameCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '1');
    String role = 'Maid';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Nocturne.palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Add Helper / Staff', style: TextStyle(color: Nocturne.palette.text, fontSize: 17, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: role,
                  dropdownColor: Nocturne.palette.surface,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  ),
                  items: [
                    DropdownMenuItem(value: 'Maid', child: Text('Maid / House Help', style: TextStyle(color: Nocturne.palette.text))),
                    DropdownMenuItem(value: 'Cook', child: Text('Cook / Chef', style: TextStyle(color: Nocturne.palette.text))),
                    DropdownMenuItem(value: 'Driver', child: Text('Driver', style: TextStyle(color: Nocturne.palette.text))),
                    DropdownMenuItem(value: 'Nanny', child: Text('Nanny / Babysitter', style: TextStyle(color: Nocturne.palette.text))),
                    DropdownMenuItem(value: 'Gardener', child: Text('Gardener', style: TextStyle(color: Nocturne.palette.text))),
                    DropdownMenuItem(value: 'Other', child: Text('Other Staff', style: TextStyle(color: Nocturne.palette.text))),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'Maid'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salaryCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Monthly Salary (₹)',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dayCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Salary Due Day of Month (e.g. 1st, 5th)',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Phone / UPI ID (Optional)',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Nocturne.palette.accent,
                foregroundColor: Nocturne.palette.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
                final day = int.tryParse(dayCtrl.text.trim()) ?? 1;
                if (name.isEmpty || salary <= 0) return;

                final ok = await s.addDomesticStaff(
                  name: name,
                  role: role,
                  monthlySalary: salary,
                  salaryDay: day.clamp(1, 31),
                  phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                );
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Helper', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRefundDialog() {
    final s = context.read<V3State>();
    final merchantCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final utrCtrl = TextEditingController();
    final appCtrl = TextEditingController(text: 'PhonePe');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Track Pending Refund', style: TextStyle(color: Nocturne.palette.text, fontSize: 17, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: merchantCtrl,
                style: TextStyle(color: Nocturne.palette.text),
                decoration: InputDecoration(
                  labelText: 'Merchant / Platform (e.g. Swiggy, Amazon, IRCTC)',
                  labelStyle: TextStyle(color: Nocturne.palette.subtle),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Nocturne.palette.text),
                decoration: InputDecoration(
                  labelText: 'Refund Amount (₹)',
                  labelStyle: TextStyle(color: Nocturne.palette.subtle),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: utrCtrl,
                style: TextStyle(color: Nocturne.palette.text),
                decoration: InputDecoration(
                  labelText: 'UTR / Transaction Ref # (12 digits)',
                  labelStyle: TextStyle(color: Nocturne.palette.subtle),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: appCtrl,
                style: TextStyle(color: Nocturne.palette.text),
                decoration: InputDecoration(
                  labelText: 'Source App (GPay, PhonePe, Paytm, HDFC)',
                  labelStyle: TextStyle(color: Nocturne.palette.subtle),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                style: TextStyle(color: Nocturne.palette.text),
                decoration: InputDecoration(
                  labelText: 'Order ID or Note (Optional)',
                  labelStyle: TextStyle(color: Nocturne.palette.subtle),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Nocturne.palette.accent,
              foregroundColor: Nocturne.palette.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final merchant = merchantCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (merchant.isEmpty || amount <= 0) return;

              final ok = await s.addPendingRefund(
                merchant: merchant,
                amount: amount,
                utrRef: utrCtrl.text.trim().isNotEmpty ? utrCtrl.text.trim() : null,
                sourceApp: appCtrl.text.trim().isNotEmpty ? appCtrl.text.trim() : 'UPI',
                notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                expectedBy: DateTime.now().add(const Duration(days: 3)),
              );
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Start Watching', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _logDeliveryBillExpense(DeliverySubscriptionRow sub, double billAmount) async {
    final s = context.read<V3State>();
    final monthStr = DateFormat('MMMM yyyy').format(_selectedMonth);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        title: Text('Log Bill as Expense', style: TextStyle(color: Nocturne.palette.text)),
        content: Text(
          'Log ${V3Design.inr(billAmount)} for "${sub.name}" ($monthStr) into your family expenses?',
          style: TextStyle(color: Nocturne.palette.neutral300),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Expense'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await s.addTransaction(
        type: 'expense',
        amount: billAmount,
        categoryKey: sub.itemType == 'newspaper' ? 'utilities' : 'groceries',
        title: '${sub.name} - $monthStr Bill',
        method: 'UPI',
        occurredAt: DateTime.now(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged ${V3Design.inr(billAmount)} for ${sub.name}!')),
        );
      }
    }
  }

  void _showStaffAdvanceDialog(DomesticStaffRow staff) {
    final s = context.read<V3State>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Log Advance for ${staff.name}', style: TextStyle(color: Nocturne.palette.text, fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: Nocturne.palette.text),
              decoration: InputDecoration(
                labelText: 'Advance Given (₹)',
                labelStyle: TextStyle(color: Nocturne.palette.subtle),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: TextStyle(color: Nocturne.palette.text),
              decoration: InputDecoration(
                labelText: 'Reason / Note (e.g. Festival, Medical)',
                labelStyle: TextStyle(color: Nocturne.palette.subtle),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              await s.addStaffLedgerEntry(
                staffId: staff.id,
                entryType: 'advance',
                amount: amt,
                date: DateTime.now(),
                note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Record Advance'),
          ),
        ],
      ),
    );
  }

  void _showStaffLeaveDialog(DomesticStaffRow staff) {
    final s = context.read<V3State>();
    final noteCtrl = TextEditingController();
    DateTime leaveDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Nocturne.palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Mark Leave for ${staff.name}', style: TextStyle(color: Nocturne.palette.text, fontSize: 16, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${DateFormat('d MMMM yyyy').format(leaveDate)}', style: TextStyle(color: Nocturne.palette.text, fontSize: 14)),
                trailing: Icon(PhRegular.calendar, color: Nocturne.palette.accentMuted, size: 20),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: leaveDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => leaveDate = picked);
                  }
                },
              ),
              TextField(
                controller: noteCtrl,
                style: TextStyle(color: Nocturne.palette.text),
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  labelStyle: TextStyle(color: Nocturne.palette.subtle),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
              onPressed: () async {
                await s.addStaffLedgerEntry(
                  staffId: staff.id,
                  entryType: 'leave',
                  amount: 0,
                  date: leaveDate,
                  note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Mark Leave'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaySalaryDialog(DomesticStaffRow staff) {
    final s = context.read<V3State>();
    final netPayable = (staff.monthlySalary - staff.advancesBalance).clamp(0.0, staff.monthlySalary);
    final monthStr = DateFormat('MMMM yyyy').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Pay Salary: ${staff.name}', style: TextStyle(color: Nocturne.palette.text, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSalaryRow('Monthly Base Salary', V3Design.inr(staff.monthlySalary)),
            if (staff.advancesBalance > 0)
              _buildSalaryRow('Less Advances Recovered', '- ${V3Design.inr(staff.advancesBalance)}', color: Nocturne.palette.expense),
            Divider(color: Nocturne.palette.faint, height: 20),
            _buildSalaryRow('Net Amount to Pay', V3Design.inr(netPayable), isTotal: true),
            const SizedBox(height: 12),
            Text(
              'Leaves this month: ${staff.leavesThisMonth} day(s)',
              style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle))),
          if (staff.phone != null && staff.phone!.isNotEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Nocturne.palette.accentLight,
                side: BorderSide(color: Nocturne.palette.switchOn),
              ),
              onPressed: () {
                UpiService.openUpiPayment(
                  upiId: staff.phone!,
                  payeeName: staff.name,
                  amount: netPayable,
                  note: 'Salary $monthStr',
                );
              },
              icon: const Icon(PhRegular.lightning, size: 16),
              label: const Text('UPI Pay'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
            onPressed: () async {
              // Log salary entry in staff ledger
              await s.addStaffLedgerEntry(
                staffId: staff.id,
                entryType: 'salary',
                amount: netPayable,
                date: DateTime.now(),
                note: 'Salary $monthStr (Adjusted advance ${V3Design.inr(staff.advancesBalance)})',
              );
              // Log to overall family expenses
              await s.addTransaction(
                type: 'expense',
                amount: netPayable,
                categoryKey: 'family',
                title: '${staff.name} (${staff.role}) - Salary $monthStr',
                method: 'Bank',
                occurredAt: DateTime.now(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Salary of ${V3Design.inr(netPayable)} recorded for ${staff.name}!')),
                );
              }
            },
            child: const Text('Record Paid'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isTotal ? Nocturne.palette.text : Nocturne.palette.subtle, fontSize: isTotal ? 14 : 13, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400)),
          Text(value, style: TextStyle(color: color ?? (isTotal ? Nocturne.palette.accentLight : Nocturne.palette.text), fontSize: isTotal ? 16 : 13, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  void _draftGrievanceComplaint(PendingRefundRow refund) {
    final daysAgo = DateTime.now().difference(refund.initiatedAt).inDays;
    final dateStr = DateFormat('dd MMM yyyy').format(refund.initiatedAt);
    final refStr = refund.utrRef?.isNotEmpty == true ? refund.utrRef! : 'N/A';

    final complaint = '''Subject: Escalation: Uncredited UPI/Merchant Refund - ₹${refund.amount.toStringAsFixed(0)} (Ref: $refStr)

Dear Grievance Officer / Support Team,

I am writing to formally raise a grievance regarding an uncredited refund of ₹${refund.amount.toStringAsFixed(0)} initiated on $dateStr from ${refund.merchant} via ${refund.sourceApp ?? 'UPI'}.

Transaction Details:
• Amount: ₹${refund.amount.toStringAsFixed(0)}
• Merchant: ${refund.merchant}
• Initiated Date: $dateStr ($daysAgo days ago)
• UTR / Reference No: $refStr
• Mode: ${refund.sourceApp ?? 'UPI'}

As per Reserve Bank of India (RBI) Harmonisation of TAT circular (DPSS.CO.PD No.629/02.01.014/2019-20), turnaround time for merchant/UPI refund credit is T+1 to T+3 working days. This transaction has now exceeded the permissible timeline ($daysAgo days pending).

Kindly investigate with the acquiring bank and expedite the immediate credit of ₹${refund.amount.toStringAsFixed(0)} to my bank account, or provide the beneficiary bank approval code for reconciliation.

Awaiting your urgent response.

Sincerely,
Account Holder''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(PhRegular.warning, color: Nocturne.palette.warning, size: 20),
            const SizedBox(width: 8),
            Text('Automated Complaint Draft', style: TextStyle(color: Nocturne.palette.text, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: SelectableText(
              complaint,
              style: TextStyle(color: Nocturne.palette.neutral300, fontSize: 12, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: TextStyle(color: Nocturne.palette.subtle))),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Nocturne.palette.accentLight,
              side: BorderSide(color: Nocturne.palette.switchOn),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: complaint));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Complaint draft copied to clipboard!')),
              );
            },
            icon: const Icon(PhRegular.copy, size: 16),
            label: const Text('Copy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
            onPressed: () {
              Share.share(complaint, subject: 'Escalation: Uncredited Refund for ₹${refund.amount.toStringAsFixed(0)}');
            },
            icon: const Icon(PhRegular.shareNetwork, size: 16),
            label: const Text('Share / Email'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD UI
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final maxH = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Nocturne.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.palette.edge, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Nocturne.palette.faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Icon(PhFill.houseLine, size: 22, color: Nocturne.palette.accentMuted),
              const SizedBox(width: 8),
              Text(
                'Household & Deliveries',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.palette.text,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(PhRegular.x, size: 20, color: Nocturne.palette.subtle),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Navigation Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TabPill(
                  label: 'Deliveries (${s.deliverySubscriptions.length})',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                _TabPill(
                  label: 'Staff Ledger (${s.domesticStaff.length})',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                const SizedBox(width: 8),
                _TabPill(
                  label: 'Refunds Watchdog (${s.pendingRefunds.where((r) => r.isPending).length})',
                  selected: _tab == 2,
                  badgeAlert: s.pendingRefunds.any((r) => r.isDelayed),
                  onTap: () => setState(() => _tab = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content body
          Expanded(
            child: switch (_tab) {
              0 => _buildDeliveriesTab(s),
              1 => _buildStaffTab(s),
              2 => _buildRefundsTab(s),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 1: DELIVERIES DIARY
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDeliveriesTab(V3State s) {
    final subs = s.deliverySubscriptions;
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Column(
      children: [
        // Month Selector Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(PhRegular.caretLeft, size: 18, color: Nocturne.palette.subtle),
              onPressed: () => setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
              }),
            ),
            Text(
              monthName,
              style: TextStyle(color: Nocturne.palette.text, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: Icon(PhRegular.caretRight, size: 18, color: Nocturne.palette.subtle),
              onPressed: () => setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
              }),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Nocturne.palette.tint,
                foregroundColor: Nocturne.palette.accentLight,
                side: BorderSide(color: Nocturne.palette.switchOn, width: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showAddSubscriptionDialog,
              icon: const Icon(PhRegular.plus, size: 14),
              label: const Text('Add Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (subs.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhRegular.basket, size: 42, color: Nocturne.palette.faint),
                  const SizedBox(height: 12),
                  Text('No daily deliveries added', style: TextStyle(color: Nocturne.palette.text, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Track milk packets, newspaper and water cans.\nTap any day a delivery was skipped for auto-billing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
                    onPressed: _showAddSubscriptionDialog,
                    child: const Text('+ Add Milk or Newspaper'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: subs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final sub = subs[i];
                final bill = sub.computeMonthlyBill(_selectedMonth.year, _selectedMonth.month);
                final prefix = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
                final skipsThisMonth = sub.skippedDates.where((d) => d.startsWith(prefix)).toSet();
                final activeDays = (daysInMonth - skipsThisMonth.length).clamp(0, daysInMonth);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Nocturne.palette.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Nocturne.palette.edge, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Icon(
                            sub.itemType == 'milk'
                                ? PhRegular.basket
                                : (sub.itemType == 'newspaper' ? PhRegular.quotes : PhRegular.tray),
                            color: Nocturne.palette.accentMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sub.name,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Nocturne.palette.text),
                            ),
                          ),
                          Text(
                            '₹${sub.unitPrice.toStringAsFixed(0)}/day',
                            style: TextStyle(fontSize: 13, color: Nocturne.palette.subtle, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (sub.vendorName != null || sub.vendorPhone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Vendor: ${sub.vendorName ?? 'Local'} ${sub.vendorPhone != null ? '(${sub.vendorPhone})' : ''}',
                          style: TextStyle(fontSize: 11, color: Nocturne.palette.muted),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Day skip picker grid (1 .. daysInMonth)
                      Text(
                        'Tap date to mark delivery as skipped:',
                        style: TextStyle(fontSize: 11, color: Nocturne.palette.subtle),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (int day = 1; day <= daysInMonth; day++) ...[
                            Builder(
                              builder: (context) {
                                final dateStr = '$prefix-${day.toString().padLeft(2, '0')}';
                                final isSkipped = skipsThisMonth.contains(dateStr);
                                return GestureDetector(
                                  onTap: () => s.toggleDeliverySkip(sub.id, dateStr),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSkipped ? Nocturne.palette.expense.withValues(alpha: 0.18) : Nocturne.palette.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSkipped ? Nocturne.palette.expense : Nocturne.palette.faint,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSkipped ? FontWeight.bold : FontWeight.w500,
                                        color: isSkipped ? Nocturne.palette.expense : Nocturne.palette.text,
                                        decoration: isSkipped ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Bill Summary & Action
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Nocturne.palette.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Nocturne.palette.faint, width: 0.8),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$activeDays days delivered · ${skipsThisMonth.length} skipped',
                                  style: TextStyle(fontSize: 11, color: Nocturne.palette.subtle),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bill: ${V3Design.inr(bill)}',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Nocturne.palette.accentLight),
                                ),
                              ],
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Nocturne.palette.accent,
                                foregroundColor: Nocturne.palette.bg,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: bill > 0 ? () => _logDeliveryBillExpense(sub, bill) : null,
                              icon: const Icon(PhRegular.floppyDisk, size: 14),
                              label: const Text('Log Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 2: DOMESTIC STAFF LEDGER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildStaffTab(V3State s) {
    final staffList = s.domesticStaff;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${staffList.length} Helper(s) on Ledger',
              style: TextStyle(color: Nocturne.palette.subtle, fontSize: 13),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Nocturne.palette.tint,
                foregroundColor: Nocturne.palette.accentLight,
                side: BorderSide(color: Nocturne.palette.switchOn, width: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showAddStaffDialog,
              icon: const Icon(PhRegular.plus, size: 14),
              label: const Text('Add Helper', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (staffList.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhRegular.users, size: 42, color: Nocturne.palette.faint),
                  const SizedBox(height: 12),
                  Text('No domestic staff added yet', style: TextStyle(color: Nocturne.palette.text, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Track monthly salaries, advances given and leave days\nfor your maid, cook, driver or nanny.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
                    onPressed: _showAddStaffDialog,
                    child: const Text('+ Add Maid / Cook / Driver'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: staffList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final staff = staffList[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Nocturne.palette.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Nocturne.palette.edge, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Nocturne.palette.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              staff.role,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Nocturne.palette.accentMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              staff.name,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Nocturne.palette.text),
                            ),
                          ),
                          Text(
                            '${V3Design.inr(staff.monthlySalary)}/mo',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Nocturne.palette.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Metrics: Due day, Advances balance, Leaves
                      Row(
                        children: [
                          _MetricChip(label: 'Salary Day', value: '${staff.salaryDay}th of month'),
                          const SizedBox(width: 8),
                          _MetricChip(
                            label: 'Advance Balance',
                            value: staff.advancesBalance > 0 ? V3Design.inr(staff.advancesBalance) : '₹0',
                            valueColor: staff.advancesBalance > 0 ? Nocturne.palette.expense : Nocturne.palette.text,
                          ),
                          const SizedBox(width: 8),
                          _MetricChip(
                            label: 'Leaves',
                            value: '${staff.leavesThisMonth} day(s)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Nocturne.palette.neutral300,
                                side: BorderSide(color: Nocturne.palette.faint),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showStaffAdvanceDialog(staff),
                              icon: const Icon(PhRegular.coins, size: 14),
                              label: const Text('Log Advance', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Nocturne.palette.neutral300,
                                side: BorderSide(color: Nocturne.palette.faint),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showStaffLeaveDialog(staff),
                              icon: const Icon(PhRegular.calendar, size: 14),
                              label: const Text('Mark Leave', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Nocturne.palette.accent,
                                foregroundColor: Nocturne.palette.bg,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showPaySalaryDialog(staff),
                              icon: const Icon(PhBold.check, size: 14),
                              label: const Text('Pay Salary', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 3: REFUNDS WATCHDOG
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRefundsTab(V3State s) {
    final allRefunds = s.pendingRefunds;
    final delayedRefunds = allRefunds.where((r) => r.isDelayed).toList();

    return Column(
      children: [
        // Delayed Overdue Banner
        if (delayedRefunds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Nocturne.palette.expense.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nocturne.palette.expense.withValues(alpha: 0.6), width: 1),
            ),
            child: Row(
              children: [
                Icon(PhRegular.warning, color: Nocturne.palette.expense, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${delayedRefunds.length} Refund(s) Exceeded RBI TAT SLA (48-72h)',
                        style: TextStyle(color: Nocturne.palette.expense, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap "Draft Grievance" on any delayed refund to send an official dispute.',
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

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${allRefunds.where((r) => r.isPending).length} Watching · ${allRefunds.where((r) => r.status == 'received').length} Settled',
              style: TextStyle(color: Nocturne.palette.subtle, fontSize: 13),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Nocturne.palette.tint,
                foregroundColor: Nocturne.palette.accentLight,
                side: BorderSide(color: Nocturne.palette.switchOn, width: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showAddRefundDialog,
              icon: const Icon(PhRegular.plus, size: 14),
              label: const Text('Track Refund', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (allRefunds.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhRegular.arrowCounterClockwise, size: 42, color: Nocturne.palette.faint),
                  const SizedBox(height: 12),
                  Text('Never lose a refund again', style: TextStyle(color: Nocturne.palette.text, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'When a UPI debit fails or a merchant initiates a refund,\nKinPurse keeps watch until the money actually hits your bank.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
                    onPressed: _showAddRefundDialog,
                    child: const Text('+ Track a Pending Refund'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: allRefunds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final r = allRefunds[i];
                final daysAgo = DateTime.now().difference(r.initiatedAt).inDays;
                final isReceived = r.status == 'received';
                final isDelayed = r.isDelayed;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Nocturne.palette.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDelayed ? Nocturne.palette.expense : (isReceived ? Nocturne.palette.income : Nocturne.palette.edge),
                      width: isDelayed ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isReceived
                                  ? Nocturne.palette.income.withValues(alpha: 0.18)
                                  : (isDelayed ? Nocturne.palette.expense.withValues(alpha: 0.18) : Nocturne.palette.edge),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isReceived ? 'RECEIVED' : (isDelayed ? 'DELAYED ($daysAgo d)' : 'PENDING'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isReceived
                                    ? Nocturne.palette.income
                                    : (isDelayed ? Nocturne.palette.expense : Nocturne.palette.subtle),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.merchant,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Nocturne.palette.text),
                            ),
                          ),
                          Text(
                            V3Design.inr(r.amount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isReceived ? Nocturne.palette.income : Nocturne.palette.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Via ${r.sourceApp ?? 'UPI'} · Initiated $daysAgo days ago (${DateFormat('d MMM').format(r.initiatedAt)})'
                        '${r.utrRef != null ? ' · Ref: ${r.utrRef}' : ''}',
                        style: TextStyle(fontSize: 11, color: Nocturne.palette.subtle),
                      ),
                      if (r.notes != null && r.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r.notes!, style: TextStyle(fontSize: 11, color: Nocturne.palette.muted)),
                      ],
                      const SizedBox(height: 10),

                      // Actions
                      Row(
                        children: [
                          if (!isReceived) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Nocturne.palette.warning,
                                side: BorderSide(color: Nocturne.palette.warning),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _draftGrievanceComplaint(r),
                              icon: const Icon(PhRegular.paperPlaneRight, size: 12),
                              label: const Text('Draft Grievance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Nocturne.palette.income,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => s.updateRefundStatus(r.id, 'received'),
                              icon: const Icon(PhBold.check, size: 12),
                              label: const Text('Mark Received', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ] else ...[
                            Icon(PhBold.checkCircle, size: 16, color: Nocturne.palette.income),
                            const SizedBox(width: 6),
                            Text('Refund credited to your account', style: TextStyle(fontSize: 12, color: Nocturne.palette.income)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => s.updateRefundStatus(r.id, 'pending'),
                              child: Text('Undo', style: TextStyle(fontSize: 11, color: Nocturne.palette.subtle)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool badgeAlert;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Nocturne.palette.accent : Nocturne.palette.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badgeAlert ? Nocturne.palette.expense : (selected ? Nocturne.palette.accent : Nocturne.palette.edge),
            width: badgeAlert ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Nocturne.palette.bg : Nocturne.palette.text,
              ),
            ),
            if (badgeAlert) ...[
              const SizedBox(width: 4),
              Icon(PhFill.warning, size: 12, color: Nocturne.palette.expense),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Nocturne.palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Nocturne.palette.faint, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Nocturne.palette.subtle)),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor ?? Nocturne.palette.text),
            ),
          ],
        ),
      ),
    );
  }
}

