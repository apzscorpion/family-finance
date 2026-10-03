import 'package:flutter/material.dart';

class ApprovalInboxScreen extends StatelessWidget {
  const ApprovalInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('Pending Approvals Inbox', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Proposals submitted by other members requiring your explicit approval before affecting your balance.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        _buildProposalCard(
          context,
          proposer: 'Rahul MN (Brother)',
          type: 'Proposed Expense Addition',
          details: '₹ 1,200.00 for Groceries (Reliance Smart)',
          reason: 'Paid from household account',
        ),
      ],
    );
  }

  Widget _buildProposalCard(
    BuildContext context, {
    required String proposer,
    required String type,
    required String details,
    required String reason,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.orangeAccent,
                  child: Icon(Icons.pending_actions, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('From $proposer', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(details, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Reason: "$reason"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proposal rejected.')),
                    );
                  },
                  child: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proposal approved! Transaction added to your ledger.')),
                    );
                  },
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
