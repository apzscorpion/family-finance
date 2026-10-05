import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';

class SamsungNotePalette {
  final int hex;
  final String name;
  final Color bg;
  final Color cardBg;
  final Color border;
  final Color accent;

  const SamsungNotePalette({
    required this.hex,
    required this.name,
    required this.bg,
    required this.cardBg,
    required this.border,
    required this.accent,
  });

  static const List<SamsungNotePalette> palettes = [
    SamsungNotePalette(
      hex: 0xFF1E2028,
      name: 'Onyx Dark',
      bg: Color(0xFF121216),
      cardBg: Color(0xFF1C1C22),
      border: Color(0xFF2C2C35),
      accent: Color(0xFF5EEAD4),
    ),
    SamsungNotePalette(
      hex: 0xFF2B2118,
      name: 'Warm Amber',
      bg: Color(0xFF1F1710),
      cardBg: Color(0xFF2B2118),
      border: Color(0xFF4A3728),
      accent: Color(0xFFFBBF24),
    ),
    SamsungNotePalette(
      hex: 0xFF162620,
      name: 'Sage Green',
      bg: Color(0xFF101C17),
      cardBg: Color(0xFF162620),
      border: Color(0xFF264237),
      accent: Color(0xFF34D399),
    ),
    SamsungNotePalette(
      hex: 0xFF172030,
      name: 'Midnight Blue',
      bg: Color(0xFF111824),
      cardBg: Color(0xFF172030),
      border: Color(0xFF273854),
      accent: Color(0xFF60A5FA),
    ),
    SamsungNotePalette(
      hex: 0xFF2D1922,
      name: 'Rose Velvet',
      bg: Color(0xFF211118),
      cardBg: Color(0xFF2D1922),
      border: Color(0xFF4D2A3A),
      accent: Color(0xFFF472B6),
    ),
    SamsungNotePalette(
      hex: 0xFF231A30,
      name: 'Deep Plum',
      bg: Color(0xFF191224),
      cardBg: Color(0xFF231A30),
      border: Color(0xFF3C2C54),
      accent: Color(0xFFA78BFA),
    ),
  ];

  static SamsungNotePalette fromHex(int? hex) {
    if (hex == null) return palettes.first;
    return palettes.firstWhere(
      (p) => p.hex == hex,
      orElse: () => palettes.first,
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _isGridView = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> _filters = [
    'All',
    'Pinned',
    'Checklists',
    'Expenses',
    'Shopping',
    'Events',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Extracts sum of any ₹ / Rs amounts inside a note's text
  static double extractNoteTotal(String content) {
    final regex = RegExp(r'(?:₹|rs\.?\s*)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
    double sum = 0;
    for (final match in regex.allMatches(content)) {
      final raw = (match.group(1) ?? '').replaceAll(',', '');
      final val = double.tryParse(raw);
      if (val != null) sum += val;
    }
    return sum;
  }

  /// Counts checklist lines (`[ ]` or `[x]` or `☐` or `☑`)
  static ({int done, int total}) checklistStats(String content) {
    final lines = content.split('\n');
    int done = 0;
    int total = 0;
    for (final l in lines) {
      final t = l.trimLeft();
      if (t.startsWith('☐ ') || t.startsWith('[ ] ')) {
        total++;
      } else if (t.startsWith('☑ ') || t.startsWith('[x] ') || t.startsWith('[X] ')) {
        total++;
        done++;
      }
    }
    return (done: done, total: total);
  }

  List<SharedNote> _filterNotes(List<SharedNote> all) {
    return all.where((n) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        final matchContent = n.content.toLowerCase().contains(q);
        final matchEditor = n.lastEditedBy.toLowerCase().contains(q);
        if (!matchTitle && !matchContent && !matchEditor) return false;
      }
      switch (_selectedFilter) {
        case 'Pinned':
          return n.isPinned;
        case 'Checklists':
          return checklistStats(n.content).total > 0;
        case 'Expenses':
          return extractNoteTotal(n.content) > 0 || n.category == 'Expenses';
        case 'Shopping':
          return n.category == 'Shopping' || n.title.toLowerCase().contains('shop') || n.title.toLowerCase().contains('grocer');
        case 'Events':
          return n.category == 'Events' || n.category == 'Wedding';
        default:
          return true;
      }
    }).toList();
  }

  void _openNoteEditor(BuildContext context, FinanceProvider provider, {SharedNote? existingNote, String? templateType}) {
    SharedNote noteToOpen;
    if (existingNote != null) {
      noteToOpen = existingNote;
    } else {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      String title = '';
      String content = '';
      String category = 'General';
      int colorHex = SamsungNotePalette.palettes.first.hex;

      if (templateType == 'checklist') {
        title = 'Monthly Grocery & Home List';
        content = '☐ Fresh Vegetables ₹250\n☐ Milk & Dairy ₹120\n☐ Rice & Staples ₹850\n☑ Cooking Oil ₹320';
        category = 'Shopping';
        colorHex = SamsungNotePalette.palettes[2].hex; // Sage Green
      } else if (templateType == 'event') {
        title = 'Family Event & Budget Plan';
        content = '☐ Venue / Catering Advance ₹15,000\n☐ Gifts & Clothes ₹5,000\n☐ Travel & Stay ₹4,500\n\nNotes:\n• Discuss with everyone on live sync';
        category = 'Events';
        colorHex = SamsungNotePalette.palettes[1].hex; // Warm Amber
      } else if (templateType == 'bills') {
        title = 'Shared Household Bills';
        content = '☐ Electricity Bill ₹1,850\n☐ Broadband Wi-Fi ₹999\n☐ Society Maintenance ₹2,500';
        category = 'Expenses';
        colorHex = SamsungNotePalette.palettes[3].hex; // Midnight Blue
      }

      noteToOpen = SharedNote(
        id: 'note_$nowMs',
        title: title,
        content: content,
        lastEditedBy: provider.currentUserName,
        lastEditedTime: 'Just now',
        categoryTag: category,
        colorHex: colorHex,
        isPinned: false,
        updatedAtMs: nowMs,
      );

      if (templateType != null) {
        provider.saveNote(noteToOpen);
      }
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secAnim) => SamsungNoteEditorScreen(initialNoteId: noteToOpen.id, draftNote: noteToOpen),
        transitionsBuilder: (ctx, anim, secAnim, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final allNotes = provider.notes;
    final filtered = _filterNotes(allNotes);
    final pinnedNotes = filtered.where((n) => n.isPinned).toList();
    final unpinnedNotes = filtered.where((n) => !n.isPinned).toList();
    final onlinePeers = provider.onlineNotePeers;
    final activeEditors = provider.activeNoteEditors;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Samsung Notes One UI Collapsible Top Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back + Live WS Status Pill + View Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => provider.setSubPage(null),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181F),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppTheme.text),
                                SizedBox(width: 6),
                                Text('Family', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.text)),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            // Live WebSocket Status Pill
                            GestureDetector(
                              onTap: () {
                                provider.reconnectNotesWs();
                                provider.showToast('Synced live room ${provider.familyCode}');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: provider.isNotesWsConnected
                                      ? const Color(0xFF102A24)
                                      : const Color(0xFF2A1818),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: provider.isNotesWsConnected
                                        ? const Color(0xFF34D399).withValues(alpha: 0.4)
                                        : Colors.orangeAccent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: provider.isNotesWsConnected
                                            ? const Color(0xFF34D399)
                                            : Colors.orangeAccent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          if (provider.isNotesWsConnected)
                                            const BoxShadow(color: Color(0xFF34D399), blurRadius: 6),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      provider.isNotesWsConnected
                                          ? 'LIVE WS · ${provider.familyCode}'
                                          : 'CONNECTING WS...',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: provider.isNotesWsConnected
                                            ? const Color(0xFF34D399)
                                            : Colors.orangeAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Grid / List View Switcher (Samsung Notes style)
                            IconButton(
                              onPressed: () => setState(() => _isGridView = !_isGridView),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF18181F),
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                              icon: Icon(
                                _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                                size: 18,
                                color: AppTheme.text,
                              ),
                              tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Samsung Notes One UI Large Title Area
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Samsung Notes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${provider.familyName} Notes',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${allNotes.length} ${allNotes.length == 1 ? 'note' : 'notes'}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Collaborators & Family Room Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF171C26), Color(0xFF13161F)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF283246)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF60A5FA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeEditors.isNotEmpty
                                  ? '✍️ ${activeEditors.values.join(", ")} editing live right now...'
                                  : onlinePeers.isNotEmpty
                                      ? 'Live with ${onlinePeers.join(", ")} in room ${provider.familyCode}'
                                      : 'Real-time WebSocket sync active for family code ${provider.familyCode}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: activeEditors.isNotEmpty
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF93C5FD),
                                fontWeight: activeEditors.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: provider.familyCode));
                              provider.showToast('Family Code ${provider.familyCode} copied!');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 11, color: Colors.white70),
                                  SizedBox(width: 4),
                                  Text('Copy Code', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Samsung Notes Search Pill
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF17171D),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF262630)),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search notes, checklists, ₹ amounts...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSubtle),
                          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppTheme.textMuted),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 17, color: AppTheme.textMuted),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Filter Chips
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final f = _filters[i];
                          final selected = _selectedFilter == f;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFilter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFFBBF24) : const Color(0xFF18181F),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected ? const Color(0xFFFBBF24) : const Color(0xFF282834),
                                ),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? Colors.black : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // Empty State with Quick Samsung Notes Templates
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.edit_note_rounded, size: 36, color: Color(0xFFFBBF24)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No shared family notes yet',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create a Samsung-style note or interactive checklist.\nEvery character & checkbox syncs live across your family over WebSocket.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.5),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _QuickTemplateChip(
                            icon: Icons.checklist_rounded,
                            label: 'Grocery Checklist',
                            color: const Color(0xFF34D399),
                            onTap: () => _openNoteEditor(context, provider, templateType: 'checklist'),
                          ),
                          _QuickTemplateChip(
                            icon: Icons.celebration_rounded,
                            label: 'Event & Budget Pad',
                            color: const Color(0xFFFBBF24),
                            onTap: () => _openNoteEditor(context, provider, templateType: 'event'),
                          ),
                          _QuickTemplateChip(
                            icon: Icons.receipt_long_rounded,
                            label: 'Monthly Bills Pad',
                            color: const Color(0xFF60A5FA),
                            onTap: () => _openNoteEditor(context, provider, templateType: 'bills'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Pinned Notes Section
              if (pinnedNotes.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22, 8, 22, 8),
                    child: Row(
                      children: [
                        Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFFFBBF24)),
                        SizedBox(width: 6),
                        Text(
                          'PINNED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildNotesSliver(context, provider, pinnedNotes),
              ],

              // Unpinned / Other Notes Section
              if (unpinnedNotes.isNotEmpty) ...[
                if (pinnedNotes.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(22, 16, 22, 8),
                      child: Text(
                        'OTHERS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                _buildNotesSliver(context, provider, unpinnedNotes),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),

      // Samsung Notes Signature Squircle Compose Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoteEditor(context, provider),
        backgroundColor: const Color(0xFFFBBF24),
        foregroundColor: Colors.black,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.edit_rounded, size: 20),
        label: const Text(
          'New Note',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
    );
  }

  Widget _buildNotesSliver(BuildContext context, FinanceProvider provider, List<SharedNote> notesList) {
    if (_isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, idx) {
              final note = notesList[idx];
              return _SamsungNoteCard(
                note: note,
                liveEditorName: provider.activeNoteEditors[note.id],
                onTap: () => _openNoteEditor(context, provider, existingNote: note),
                onTogglePin: () => provider.togglePinNote(note.id),
                onDelete: () => provider.deleteNote(note.id),
              );
            },
            childCount: notesList.length,
          ),
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, idx) {
              final note = notesList[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SamsungNoteCard(
                  note: note,
                  isListMode: true,
                  liveEditorName: provider.activeNoteEditors[note.id],
                  onTap: () => _openNoteEditor(context, provider, existingNote: note),
                  onTogglePin: () => provider.togglePinNote(note.id),
                  onDelete: () => provider.deleteNote(note.id),
                ),
              );
            },
            childCount: notesList.length,
          ),
        ),
      );
    }
  }
}

class _QuickTemplateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickTemplateChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF181820),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _SamsungNoteCard extends StatelessWidget {
  final SharedNote note;
  final bool isListMode;
  final String? liveEditorName;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _SamsungNoteCard({
    required this.note,
    this.isListMode = false,
    this.liveEditorName,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = SamsungNotePalette.fromHex(note.colorHex);
    final stats = _NotesScreenState.checklistStats(note.content);
    final totalAmount = _NotesScreenState.extractNoteTotal(note.content);
    final lines = note.content.split('\n').where((l) => l.trim().isNotEmpty).take(isListMode ? 4 : 6).toList();

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1C1C24),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    color: const Color(0xFFFBBF24),
                  ),
                  title: Text(
                    note.isPinned ? 'Unpin note' : 'Pin to top',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onTogglePin();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('Delete note for everyone', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: liveEditorName != null ? const Color(0xFFFBBF24) : palette.border,
            width: liveEditorName != null ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title + Pin Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    note.title.trim().isEmpty ? 'Untitled Note' : note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ),
                if (note.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFFFBBF24)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Live Editor Real-Time Indicator
            if (liveEditorName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '✍️ $liveEditorName editing live...',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ),

            // Preview Body (Renders Samsung Notes Checkboxes cleanly)
            if ( isListMode )
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((line) => _buildPreviewLine(line, palette.accent)).toList(),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines.map((line) => _buildPreviewLine(line, palette.accent)).toList(),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Checklist Progress or ₹ Total Pill
            if (stats.total > 0 || totalAmount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (stats.total > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '☑ ${stats.done}/${stats.total}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.accent),
                        ),
                      ),
                    if (totalAmount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Footer Metadata
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${note.lastEditedBy} · ${note.updatedAt}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewLine(String rawLine, Color accent) {
    final trimmed = rawLine.trimLeft();
    if (trimmed.startsWith('☑ ') || trimmed.startsWith('[x] ') || trimmed.startsWith('[X] ')) {
      final text = trimmed.replaceFirst(RegExp(r'^(☑|\[[xX]\])\s*'), '');
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Icon(Icons.check_box_rounded, size: 13, color: accent),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white38,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (trimmed.startsWith('☐ ') || trimmed.startsWith('[ ] ')) {
      final text = trimmed.replaceFirst(RegExp(r'^(☐|\[\s\])\s*'), '');
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            const Icon(Icons.check_box_outline_blank_rounded, size: 13, color: Colors.white54),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        trimmed,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.35),
      ),
    );
  }
}

/// Full-Screen Samsung Notes One UI Live Collaborative Editor
class SamsungNoteEditorScreen extends StatefulWidget {
  final String initialNoteId;
  final SharedNote draftNote;

  const SamsungNoteEditorScreen({
    super.key,
    required this.initialNoteId,
    required this.draftNote,
  });

  @override
  State<SamsungNoteEditorScreen> createState() => _SamsungNoteEditorScreenState();
}

class _SamsungNoteEditorScreenState extends State<SamsungNoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  final TextEditingController _newCheckItemCtrl = TextEditingController();

  late String _category;
  late int _colorHex;
  late bool _isPinned;
  int _lastSeenUpdatedAtMs = 0;
  Timer? _liveBroadcastDebounce;

  static const List<String> _categories = [
    'General',
    'Shopping',
    'Expenses',
    'Events',
    'Important',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.draftNote.title);
    _contentCtrl = TextEditingController(text: widget.draftNote.content);
    _category = widget.draftNote.category;
    _colorHex = widget.draftNote.colorHex;
    _isPinned = widget.draftNote.isPinned;
    _lastSeenUpdatedAtMs = widget.draftNote.updatedAtMs;
  }

  @override
  void dispose() {
    _liveBroadcastDebounce?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _newCheckItemCtrl.dispose();
    super.dispose();
  }

  /// Streams the note live over WebSocket as the user edits (debounced 120ms)
  void _onLocalEditChanged(FinanceProvider provider) {
    provider.notifyNoteTyping(widget.initialNoteId);
    _liveBroadcastDebounce?.cancel();
    _liveBroadcastDebounce = Timer(const Duration(milliseconds: 120), () {
      _persistAndBroadcast(provider);
    });
    setState(() {});
  }

  void _persistAndBroadcast(FinanceProvider provider) {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text;
    if (title.isEmpty && content.trim().isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _lastSeenUpdatedAtMs = nowMs;

    final nowTime = TimeOfDay.now();
    final formattedTime =
        '${nowTime.hourOfPeriod == 0 ? 12 : nowTime.hourOfPeriod}:${nowTime.minute.toString().padLeft(2, '0')} ${nowTime.period == DayPeriod.am ? 'AM' : 'PM'}';

    final updatedNote = SharedNote(
      id: widget.initialNoteId,
      title: title.isEmpty ? 'Untitled Note' : title,
      content: content,
      lastEditedBy: provider.currentUserName,
      lastEditedTime: formattedTime,
      categoryTag: _category,
      colorHex: _colorHex,
      isPinned: _isPinned,
      updatedAtMs: nowMs,
    );
    provider.saveNote(updatedNote, broadcast: true);
  }

  /// Sync incoming remote WebSocket edits into the live text controllers without losing cursor
  void _syncFromRemoteIfNewer(SharedNote? storeNote) {
    if (storeNote == null) return;
    if (storeNote.updatedAtMs > _lastSeenUpdatedAtMs) {
      _lastSeenUpdatedAtMs = storeNote.updatedAtMs;
      if (_titleCtrl.text != storeNote.title) {
        final sel = _titleCtrl.selection;
        _titleCtrl.text = storeNote.title;
        if (sel.baseOffset <= _titleCtrl.text.length) {
          _titleCtrl.selection = sel;
        }
      }
      if (_contentCtrl.text != storeNote.content) {
        final sel = _contentCtrl.selection;
        _contentCtrl.text = storeNote.content;
        if (sel.baseOffset <= _contentCtrl.text.length) {
          _contentCtrl.selection = sel;
        }
      }
      _category = storeNote.category;
      _colorHex = storeNote.colorHex;
      _isPinned = storeNote.isPinned;
    }
  }

  /// Toggle a checklist line `☐` <-> `☑` at a specific line index and broadcast live
  void _toggleChecklistLine(int lineIndex, FinanceProvider provider) {
    final lines = _contentCtrl.text.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    final line = lines[lineIndex];
    if (line.trimLeft().startsWith('☐ ')) {
      lines[lineIndex] = line.replaceFirst('☐ ', '☑ ');
    } else if (line.trimLeft().startsWith('☑ ')) {
      lines[lineIndex] = line.replaceFirst('☑ ', '☐ ');
    } else if (line.trimLeft().startsWith('[ ] ')) {
      lines[lineIndex] = line.replaceFirst('[ ] ', '☑ ');
    } else if (line.trimLeft().startsWith('[x] ') || line.trimLeft().startsWith('[X] ')) {
      lines[lineIndex] = line.replaceFirst(RegExp(r'\[[xX]\] '), '☐ ');
    }
    _contentCtrl.text = lines.join('\n');
    _persistAndBroadcast(provider);
    setState(() {});
  }

  void _insertSnippet(String snippet, FinanceProvider provider) {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    if (sel.isValid && sel.baseOffset >= 0 && sel.baseOffset <= text.length) {
      final before = text.substring(0, sel.baseOffset);
      final after = text.substring(sel.extentOffset);
      final prefix = (before.isNotEmpty && !before.endsWith('\n') && snippet.startsWith('\n'))
          ? ''
          : '';
      final inserted = '$before$prefix$snippet$after';
      _contentCtrl.text = inserted;
      _contentCtrl.selection = TextSelection.collapsed(offset: before.length + snippet.length);
    } else {
      final sep = text.isEmpty || text.endsWith('\n') ? '' : '\n';
      _contentCtrl.text = '$text$sep$snippet';
      _contentCtrl.selection = TextSelection.collapsed(offset: _contentCtrl.text.length);
    }
    _onLocalEditChanged(provider);
  }

  void _showPalettePicker(FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Samsung Notes Page Color',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: SamsungNotePalette.palettes.map((p) {
                  final selected = p.hex == _colorHex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _colorHex = p.hex);
                      _persistAndBroadcast(provider);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: p.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? p.accent : p.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: p.accent,
                              shape: BoxShape.circle,
                            ),
                            child: selected
                                ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.name,
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final storeNote = provider.notes.where((n) => n.id == widget.initialNoteId).firstOrNull;
    _syncFromRemoteIfNewer(storeNote);

    final palette = SamsungNotePalette.fromHex(_colorHex);
    final liveEditor = provider.activeNoteEditors[widget.initialNoteId];
    final totalAmount = _NotesScreenState.extractNoteTotal(_contentCtrl.text);
    final lines = _contentCtrl.text.split('\n');
    final checklistIndices = <int>[];
    for (int i = 0; i < lines.length; i++) {
      final t = lines[i].trimLeft();
      if (t.startsWith('☐ ') || t.startsWith('☑ ') || t.startsWith('[ ] ') || t.startsWith('[x] ') || t.startsWith('[X] ')) {
        checklistIndices.add(i);
      }
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        _persistAndBroadcast(provider);
      },
      child: Scaffold(
        backgroundColor: palette.bg,
        appBar: AppBar(
          backgroundColor: palette.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
            onPressed: () {
              _persistAndBroadcast(provider);
              Navigator.of(context).pop();
            },
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              // Category Dropdown Pill
              PopupMenuButton<String>(
                initialValue: _category,
                color: const Color(0xFF20202A),
                onSelected: (val) {
                  setState(() => _category = val);
                  _persistAndBroadcast(provider);
                },
                itemBuilder: (ctx) => _categories
                    .map((c) => PopupMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 13, color: palette.accent),
                      const SizedBox(width: 5),
                      Text(
                        _category,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Live Sync Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'LIVE',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF34D399)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                size: 20,
                color: _isPinned ? const Color(0xFFFBBF24) : Colors.white70,
              ),
              tooltip: 'Pin Note',
              onPressed: () {
                setState(() => _isPinned = !_isPinned);
                _persistAndBroadcast(provider);
              },
            ),
            IconButton(
              icon: Icon(Icons.palette_outlined, size: 20, color: palette.accent),
              tooltip: 'Page Background Color',
              onPressed: () => _showPalettePicker(provider),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 19, color: Colors.white70),
              tooltip: 'Copy Note to Share',
              onPressed: () {
                final textToCopy = '${_titleCtrl.text}\n\n${_contentCtrl.text}\n\n— Shared via ${provider.familyName} Live Notes (${provider.familyCode})';
                Clipboard.setData(ClipboardData(text: textToCopy));
                provider.showToast('Note copied to clipboard!');
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
              tooltip: 'Delete Note',
              onPressed: () {
                provider.deleteNote(widget.initialNoteId);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Live Collaborator Typing Banner
            if (liveEditor != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                color: const Color(0xFFFBBF24).withValues(alpha: 0.16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFBBF24)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '✍️ $liveEditor is editing this note live via WebSocket...',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFBBF24)),
                    ),
                  ],
                ),
              ),

            // Auto-Calculated Expense Total Banner (when ₹ amounts exist)
            if (totalAmount > 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: palette.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate_outlined, size: 17, color: palette.accent),
                        const SizedBox(width: 8),
                        const Text(
                          'Auto Expense Sum in Note',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
              ),

            // Main Samsung Notes Scrollable Canvas
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Note Title Input
                    TextField(
                      controller: _titleCtrl,
                      onChanged: (_) => _onLocalEditChanged(provider),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white24),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Metadata Timestamp & Live Room Info
                    Row(
                      children: [
                        Text(
                          'Edited by ${storeNote?.lastEditedBy ?? provider.currentUserName} · ${storeNote?.updatedAt ?? "Live"}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white38),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Room ${provider.familyCode}',
                            style: TextStyle(fontSize: 10, color: palette.accent),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 22),

                    // Interactive One-Tap Checklists Card (if note has checklist items)
                    if (checklistIndices.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.checklist_rtl_rounded, size: 15, color: palette.accent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Interactive Live Checklist (Tap to check)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: palette.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_NotesScreenState.checklistStats(_contentCtrl.text).done}/${checklistIndices.length} done',
                                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...checklistIndices.map((lineIdx) {
                              final raw = lines[lineIdx].trimLeft();
                              final checked = raw.startsWith('☑ ') || raw.startsWith('[x] ') || raw.startsWith('[X] ');
                              final label = raw.replaceFirst(RegExp(r'^(☐|☑|\[\s\]|\[[xX]\])\s*'), '');
                              return InkWell(
                                onTap: () => _toggleChecklistLine(lineIdx, provider),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        checked
                                            ? Icons.check_box_rounded
                                            : Icons.check_box_outline_blank_rounded,
                                        size: 19,
                                        color: checked ? palette.accent : Colors.white60,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: checked ? Colors.white38 : Colors.white,
                                            decoration: checked ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    // Seamless Samsung Notes Full-Page Text Canvas
                    TextField(
                      controller: _contentCtrl,
                      onChanged: (_) => _onLocalEditChanged(provider),
                      maxLines: null,
                      minLines: 14,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 15.5,
                        color: Colors.white,
                        height: 1.6,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Start typing your shared note, checklist, or ₹ expenses...\n\nChanges stream live to family members in real time.',
                        hintStyle: TextStyle(fontSize: 14.5, color: Colors.white24, height: 1.5),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Samsung Notes Bottom Formatting Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.cardBg,
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ToolbarButton(
                        icon: Icons.check_box_outlined,
                        label: 'Checklist',
                        accent: palette.accent,
                        onTap: () => _insertSnippet('\n☐ ', provider),
                      ),
                      const SizedBox(width: 8),
                      _ToolbarButton(
                        icon: Icons.format_list_bulleted_rounded,
                        label: 'Bullet',
                        accent: palette.accent,
                        onTap: () => _insertSnippet('\n• ', provider),
                      ),
                      const SizedBox(width: 8),
                      _ToolbarButton(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Amount ₹',
                        accent: const Color(0xFFFBBF24),
                        onTap: () => _insertSnippet(' ₹', provider),
                      ),
                      const SizedBox(width: 8),
                      _ToolbarButton(
                        icon: Icons.palette_outlined,
                        label: 'Color',
                        accent: palette.accent,
                        onTap: () => _showPalettePicker(provider),
                      ),
                      const SizedBox(width: 8),
                      _ToolbarButton(
                        icon: Icons.schedule_rounded,
                        label: 'Timestamp',
                        accent: Colors.white70,
                        onTap: () {
                          final now = TimeOfDay.now();
                          _insertSnippet(' [${now.format(context)}] ', provider);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
