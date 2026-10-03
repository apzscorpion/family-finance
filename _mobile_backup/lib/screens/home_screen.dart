import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Total Tracked Balance Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Tracked Balance', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('₹ 1,45,250.00', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Income Earned', '₹ 75,000', Colors.green),
                    _buildStatItem('Expenses', '₹ 29,750', Colors.red),
                    _buildStatItem('Net Flow', '+₹ 45,250', Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Financial Accuracy Warning Banner (Loan Disbursements != Earned Income)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Note: ₹5,000 Personal Loan disbursement is tracked as liability inflow and excluded from earned profit.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('Spending by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        _buildCategoryProgress('Food & Dining', 0.42, '₹ 12,500', Colors.orange),
        _buildCategoryProgress('Transportation', 0.25, '₹ 7,400', Colors.blue),
        _buildCategoryProgress('Utilities & Bills', 0.18, '₹ 5,350', Colors.purple),
        _buildCategoryProgress('Shopping', 0.15, '₹ 4,500', Colors.teal),
      ],
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCategoryProgress(String category, double percent, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percent,
            color: color,
            backgroundColor: color.withOpacity(0.15),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
