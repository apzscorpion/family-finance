import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  void _showNoteDialog(BuildContext context, FinanceProvider provider, [SharedNote? note]) {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note == null ? 'New Shared Note' : 'Edit Shared Note',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text),
                decoration: const InputDecoration(
                  hintText: 'Note Title (e.g., Wedding Planning)',
                  hintStyle: TextStyle(color: AppTheme.textSubtle),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                style: const TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: const InputDecoration(
                  hintText: 'Add note details, shopping list, or event expenses...',
                  hintStyle: TextStyle(color: AppTheme.textSubtle),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    provider.saveNote(SharedNote(
                      id: note?.id ?? 'n_${DateTime.now().millisecondsSinceEpoch}',
                      title: titleCtrl.text.trim(),
                      content: contentCtrl.text.trim(),
                      lastEditedBy: provider.currentUserName,
                      lastEditedTime: 'Just now',
                    ));
                    Navigator.pop(ctx);
                    provider.showToast(note == null ? 'Note created & shared with family' : 'Note updated');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(note == null ? 'Share Note' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => provider.closeSubPage(),
        ),
        title: const Text('Shared Family Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.text)),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_outlined, color: AppTheme.accent200),
            onPressed: () => _showNoteDialog(context, provider),
          ),
        ],
      ),
      body: provider.notes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_alt_outlined, size: 48, color: AppTheme.textSubtle),
                  const SizedBox(height: 12),
                  const Text('No shared notes yet', style: TextStyle(fontSize: 15, color: AppTheme.text)),
                  const SizedBox(height: 4),
                  const Text('Create notes for wedding expenses, loans, or shopping lists', style: TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showNoteDialog(context, provider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Shared Note'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent900, foregroundColor: AppTheme.accent200),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: provider.notes.length,
              itemBuilder: (ctx, i) {
                final note = provider.notes[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF3F424D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(note.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text)),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSubtle),
                            onPressed: () => _showNoteDialog(context, provider, note),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(note.content, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.accent900, borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: [
                                const Icon(Icons.edit_note, size: 12, color: AppTheme.accent200),
                                const SizedBox(width: 4),
                                Text('Edited by ${note.lastEditedBy} · ${note.lastEditedTime}', style: const TextStyle(fontSize: 11, color: AppTheme.accent200)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
