import 'package:flutter/material.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Search & Filter Bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Search merchant, category, or note...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // Date Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(label: const Text('Today'), selected: false, onSelected: (_) {}),
              const SizedBox(width: 8),
              FilterChip(label: const Text('This Week'), selected: false, onSelected: (_) {}),
              const SizedBox(width: 8),
              FilterChip(label: const Text('This Month'), selected: true, onSelected: (_) {}),
              const SizedBox(width: 8),
              FilterChip(label: const Text('All Members'), selected: true, onSelected: (_) {}),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildTransactionTile('Swiggy', 'Food', '₹ 450.00', 'Today, 2:30 PM', Icons.fastfood, Colors.orange, 'UPI'),
        _buildTransactionTile('Auto Fare', 'Transportation', '₹ 150.00', 'Today, 11:15 AM', Icons.directions_car, Colors.blue, 'Cash'),
        _buildTransactionTile('Monthly Salary', 'Income', '₹ 75,000.00', 'Yesterday', Icons.account_balance_wallet, Colors.green, 'Bank', isIncome: true),
        _buildTransactionTile('Rahul Transfer', 'Transfer Out', '₹ 2,000.00', '01 Oct 2026', Icons.compare_arrows, Colors.purple, 'UPI', isTransfer: true),
      ],
    );
  }

  Widget _buildTransactionTile(
    String title,
    String category,
    String amount,
    String time,
    IconData icon,
    Color color,
    String method, {
    bool isIncome = false,
    bool isTransfer = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$category • $method • $time'),
        trailing: Text(
          isIncome ? '+$amount' : (isTransfer ? amount : '-$amount'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isIncome ? Colors.green : (isTransfer ? Colors.purple : Colors.red),
          ),
        ),
      ),
    );
  }
}
