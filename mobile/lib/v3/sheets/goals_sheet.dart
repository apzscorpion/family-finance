import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

class GoalsSheet extends StatelessWidget {
  const GoalsSheet({super.key});

  static Future<void> open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _GoalsSheetShell(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _GoalsSheetShell();
  }
}

class _GoalsSheetShell extends StatelessWidget {
  const _GoalsSheetShell();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final goals = s.goals;
    final totalTarget = goals.fold<double>(0.0, (acc, g) => acc + g.targetAmount);
    final totalSaved = goals.fold<double>(0.0, (acc, g) => acc + g.currentAmount);
    final overallProgress = totalTarget <= 0 ? 0.0 : (totalSaved / totalTarget).clamp(0.0, 1.0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: Nocturne.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Savings Goals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Nocturne.palette.text,
                      ),
                    ),
                    Text(
                      'Save together for big milestones and shared aspirations',
                      style: TextStyle(fontSize: 12, color: Nocturne.palette.muted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Nocturne.palette.accent,
                  foregroundColor: Nocturne.palette.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openNewGoalDialog(context, s),
                icon: const Icon(PhRegular.plus, size: 14),
                label: const Text(
                  'New Goal',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (goals.isNotEmpty) ...[
            // Overall summary banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Nocturne.palette.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: overallProgress,
                          strokeWidth: 4.5,
                          backgroundColor: Nocturne.palette.edge,
                          valueColor: AlwaysStoppedAnimation(Nocturne.palette.income),
                        ),
                        Text(
                          '${(overallProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Nocturne.palette.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${V3Design.inr(totalSaved)} saved',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Nocturne.palette.text,
                          ),
                        ),
                        Text(
                          'of ${V3Design.inr(totalTarget)} target across ${goals.length} goal${goals.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: Nocturne.palette.subtle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // List of goals
          Expanded(
            child: goals.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Nocturne.palette.bg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(PhRegular.target,
                                size: 32, color: Nocturne.palette.accentMuted),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No savings goals yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Nocturne.palette.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Plan an Umrah trip, holiday, car, or emergency buffer.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Nocturne.palette.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: goals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _GoalCard(goal: goals[i]),
                  ),
          ),
        ],
      ),
    );
  }

  static void _openNewGoalDialog(BuildContext context, V3State s) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final initialCtrl = TextEditingController();
    DateTime? selectedDate;

    showDialog<void>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Nocturne.palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Create Savings Goal',
            style: TextStyle(
              color: Nocturne.palette.text,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Goal Name',
                    hintText: 'e.g. Umrah 2027, Emergency Fund',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                    hintStyle: TextStyle(color: Nocturne.palette.faint),
                    filled: true,
                    fillColor: Nocturne.palette.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Target Amount (₹)',
                    hintText: 'e.g. 300000',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                    hintStyle: TextStyle(color: Nocturne.palette.faint),
                    filled: true,
                    fillColor: Nocturne.palette.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: initialCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Nocturne.palette.text),
                  decoration: InputDecoration(
                    labelText: 'Already Saved Amount (₹, optional)',
                    hintText: '0',
                    labelStyle: TextStyle(color: Nocturne.palette.subtle),
                    hintStyle: TextStyle(color: Nocturne.palette.faint),
                    filled: true,
                    fillColor: Nocturne.palette.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: Nocturne.palette.accent,
                            surface: Nocturne.palette.surface,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Nocturne.palette.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(PhRegular.calendar, size: 16, color: Nocturne.palette.subtle),
                        const SizedBox(width: 8),
                        Text(
                          selectedDate == null
                              ? 'Target Date (Optional)'
                              : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                          style: TextStyle(
                            fontSize: 13,
                            color: selectedDate == null
                                ? Nocturne.palette.muted
                                : Nocturne.palette.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Nocturne.palette.accent,
                foregroundColor: Nocturne.palette.bg,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final target = double.tryParse(targetCtrl.text.trim()) ?? 0;
                final initial = double.tryParse(initialCtrl.text.trim()) ?? 0;
                if (name.isNotEmpty && target > 0) {
                  Navigator.pop(dlgCtx);
                  await s.createGoal(
                    name: name,
                    targetAmount: target,
                    initialAmount: initial,
                    targetDate: selectedDate,
                  );
                }
              },
              child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final GoalRow goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final s = context.read<V3State>();
    final progress = goal.progress;
    final remaining = goal.remainingAmount;
    final months = goal.remainingMonths;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Nocturne.palette.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goal.isCompleted
              ? Nocturne.palette.income.withValues(alpha: 0.4)
              : Nocturne.palette.edge,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: goal.isCompleted
                      ? Nocturne.palette.income.withValues(alpha: 0.15)
                      : Nocturne.palette.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  goal.isCompleted ? PhRegular.checkCircle : PhRegular.target,
                  size: 18,
                  color: goal.isCompleted
                      ? Nocturne.palette.income
                      : Nocturne.palette.accentMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.palette.text,
                      ),
                    ),
                    Text(
                      goal.isCompleted
                          ? 'Goal reached! 🎉'
                          : months != null && months > 0
                              ? '${V3Design.inr(remaining)} remaining · ~$months mos'
                              : '${V3Design.inr(remaining)} remaining',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: goal.isCompleted
                            ? Nocturne.palette.income
                            : Nocturne.palette.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(PhRegular.dotsThreeVertical, size: 16, color: Nocturne.palette.muted),
                color: Nocturne.palette.surface,
                onSelected: (val) {
                  if (val == 'add') {
                    _openContributeDialog(context, s, goal);
                  } else if (val == 'delete') {
                    s.deleteGoal(goal.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'add',
                    child: Text('Add Savings', style: TextStyle(color: Nocturne.palette.text)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Goal', style: TextStyle(color: Nocturne.palette.expense)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Nocturne.palette.edge,
              valueColor: AlwaysStoppedAnimation(
                goal.isCompleted ? Nocturne.palette.income : Nocturne.palette.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${V3Design.inr(goal.currentAmount)} / ${V3Design.inr(goal.targetAmount)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Nocturne.palette.text),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: goal.isCompleted ? Nocturne.palette.income : Nocturne.palette.accentMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick add contribution button
          if (!goal.isCompleted)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _openContributeDialog(context, s, goal),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Nocturne.palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Nocturne.palette.switchOn, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhRegular.plus, size: 12, color: Nocturne.palette.accentMuted),
                      SizedBox(width: 4),
                      Text(
                        'Add Money',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.palette.accentMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static void _openContributeDialog(BuildContext context, V3State s, GoalRow goal) {
    final amountCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add to "${goal.name}"',
          style: TextStyle(
            color: Nocturne.palette.text,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: TextStyle(color: Nocturne.palette.text),
          decoration: InputDecoration(
            labelText: 'Deposit Amount (₹)',
            hintText: 'e.g. 5000',
            labelStyle: TextStyle(color: Nocturne.palette.subtle),
            hintStyle: TextStyle(color: Nocturne.palette.faint),
            filled: true,
            fillColor: Nocturne.palette.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Nocturne.palette.accent,
              foregroundColor: Nocturne.palette.bg,
            ),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amt > 0) {
                Navigator.pop(dlgCtx);
                await s.contributeGoal(goal.id, amt);
              }
            },
            child: const Text('Deposit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

