import 'package:flutter/material.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = 'EXPENSE';
  String _selectedCategory = 'Food';
  String _selectedMember = 'Self';
  bool _isProposal = false;

  final List<String> _categories = [
    'Food', 'Transportation', 'Fuel', 'Rent', 'Utilities',
    'Shopping', 'Medical', 'Education', 'Gifts', 'Business'
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Button: Expense vs Income
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'EXPENSE', label: Text('Expense'), icon: Icon(Icons.arrow_downward)),
              ButtonSegment(value: 'INCOME', label: Text('Income'), icon: Icon(Icons.arrow_upward)),
            ],
            selected: {_selectedType},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedType = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 20),

          // Amount Keypad Input
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Target Member Selector (Self vs Other Family Member)
          DropdownButtonFormField<String>(
            value: _selectedMember,
            decoration: const InputDecoration(labelText: 'Target Member', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Self', child: Text('Self (My Record)')),
              DropdownMenuItem(value: 'Wife (Sarah)', child: Text('Wife (Sarah)')),
              DropdownMenuItem(value: 'Brother (Rahul)', child: Text('Brother (Rahul)')),
            ],
            onChanged: (val) {
              setState(() {
                _selectedMember = val!;
                _isProposal = (val != 'Self');
              });
            },
          ),
          const SizedBox(height: 16),

          if (_isProposal)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Adding on behalf of Sarah. This will be submitted as a collaborative proposal for Sarah\'s approval.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Category Dropdown
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
          ),
          const SizedBox(height: 16),

          // Description & Notes
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Merchant / Note (e.g. Swiggy, Auto Fare)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final text = _isProposal
                    ? 'Submitted proposal for $_selectedMember approval!'
                    : 'Transaction saved successfully!';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
                _amountController.clear();
                _descController.clear();
              },
              child: Text(_isProposal ? 'Submit Proposal' : 'Save Transaction', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
