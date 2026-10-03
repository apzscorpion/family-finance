import 'package:flutter/material.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Organization Header Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.groups, size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Our Family', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('3 of 30 members', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Invite'),
                  onPressed: () {
                    _showInviteDialog(context);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text('Member Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        _buildMemberTile('Asif MN', 'Owner', 'Self', Icons.security, Colors.amber),
        _buildMemberTile('Sarah MN', 'Member', 'Wife', Icons.favorite, Colors.purple),
        _buildMemberTile('Rahul MN', 'Admin', 'Brother', Icons.shield, Colors.blue),
      ],
    );
  }

  Widget _buildMemberTile(String name, String role, String relation, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Relationship: $relation'),
        trailing: Chip(
          label: Text(role, style: const TextStyle(fontSize: 12)),
          backgroundColor: color.withOpacity(0.1),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Family Member'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Email or Phone Number')),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'Relationship (e.g. Wife, Brother)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expiring invitation link generated!')),
              );
            },
            child: const Text('Generate Invitation Link'),
          ),
        ],
      ),
    );
  }
}
