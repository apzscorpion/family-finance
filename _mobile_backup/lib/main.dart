import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/family_screen.dart';
import 'screens/approval_inbox_screen.dart';

void main() {
  runApp(const FamilyFinanceApp());
}

class FamilyFinanceApp extends StatelessWidget {
  const FamilyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family & Personal Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E88E5), // Trust Blue
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E88E5),
        brightness: Brightness.dark,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _activeMemberContext = "Owner (Self)";

  final List<Widget> _screens = [
    const HomeScreen(),
    const TransactionsScreen(),
    const AddTransactionScreen(),
    const ApprovalInboxScreen(),
    const FamilyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Finance Manager'),
        actions: [
          // Member Switcher Dropdown for Organization View Context
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Switch Member View Context',
            onSelected: (String memberName) {
              setState(() {
                _activeMemberContext = memberName;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Switched view context to $memberName')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Owner (Self)',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Owner (Self)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Wife (Sarah)',
                child: Row(
                  children: [
                    Icon(Icons.face, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Wife (Sarah)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Brother (Rahul)',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Brother (Rahul)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Member Context Banner
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.visibility, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Active View Context: $_activeMemberContext',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                if (_activeMemberContext != 'Owner (Self)')
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _activeMemberContext = 'Owner (Self)';
                      });
                    },
                    child: const Text('Reset Context'),
                  )
              ],
            ),
          ),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.add_circle), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.inbox), label: 'Approvals'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Family'),
        ],
      ),
    );
  }
}
