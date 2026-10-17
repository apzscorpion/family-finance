import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../../theme/nocturne_palette.dart';
import '../data/ai/ai_config.dart';
import '../data/ai/ask_kinpurse_engine.dart';
import '../data/prayer/prayer_controller.dart';
import '../phosphor_icons.dart';
import '../sheets/update_sheet_v3.dart';
import '../sheets/v3_sheets.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import 'categories_manager_v3.dart';
import 'import_v3.dart';
import 'sources_manager_v3.dart';

class AskKinPurseMessage {
  final bool isUser;
  final String text;
  final AskKinPurseResult? result;
  final DateTime timestamp;

  AskKinPurseMessage({
    required this.isUser,
    required this.text,
    this.result,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AskKinPurseScreen extends StatefulWidget {
  const AskKinPurseScreen({super.key});

  @override
  State<AskKinPurseScreen> createState() => _AskKinPurseScreenState();
}

class _AskKinPurseScreenState extends State<AskKinPurseScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AskKinPurseMessage> _messages = [];
  bool _thinking = false;
  AiConfig? _aiConfig;

  static const List<String> _suggestedPrompts = [
    'How much did we spend on groceries last month vs this month?',
    'What was our biggest expense in the last 30 days?',
    'How much did we spend on food delivery recently?',
    'How do I set a budget?',
  ];

  @override
  void initState() {
    super.initState();
    _loadAiConfig();
  }

  Future<void> _loadAiConfig() async {
    final cfg = await AiConfigStore.load();
    if (mounted) setState(() => _aiConfig = cfg);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _ask(String question) async {
    final clean = question.trim();
    if (clean.isEmpty) return;

    final config = _aiConfig;
    if (config == null || !config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configure an AI provider in Settings first.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => context.read<V3Nav>().goPage(V3Page.aiSettings),
          ),
        ),
      );
      return;
    }

    _inputController.clear();
    setState(() {
      _messages.add(AskKinPurseMessage(isUser: true, text: clean));
      _thinking = true;
    });
    _scrollToBottom();

    final s = context.read<V3State>();
    // The last answered question, so "exclude loan account" refines it.
    final last = _messages.reversed
        .where((m) => !m.isUser && m.result?.query != null)
        .firstOrNull;
    final lastQuestion = _messages.reversed
        .skip(1)
        .where((m) => m.isUser)
        .firstOrNull;
    final result = await AskKinPurseEngine.ask(
      question: clean,
      config: config,
      txns: s.txns,
      categories: s.categories,
      members: s.members,
      myName: s.me?.name ?? 'User',
      sources: s.sources,
      sourceOf: s.sourceOf,
      previous: last?.result?.query,
      previousQuestion: lastQuestion?.text,
    );

    if (!mounted) return;

    setState(() {
      _thinking = false;
      _messages.add(AskKinPurseMessage(
        isUser: false,
        text: result.answerText,
        result: result,
      ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Privacy Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Nocturne.palette.surface,
          child: Row(
            children: [
              Icon(PhRegular.lockSimple, size: 13, color: Nocturne.palette.accentMuted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'On-device privacy: your actual spending amounts never leave this device. The AI only interprets the search query.',
                  style: TextStyle(fontSize: 11, color: Nocturne.palette.subtle),
                ),
              ),
            ],
          ),
        ),

        // Chat conversation / Empty State
        Expanded(
          child: _messages.isEmpty ? _buildEmptyState() : _buildChatList(),
        ),

        if (_thinking)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Nocturne.palette.accentMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Analyzing question and calculating locally...',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Nocturne.palette.subtle,
                  ),
                ),
              ],
            ),
          ),

        // Input Bar
        _buildInputBar(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Nocturne.palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Nocturne.palette.edge),
            ),
            child: Icon(PhRegular.sparkle, size: 28, color: Nocturne.palette.accentMuted),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Ask anything about your money',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Nocturne.palette.text,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Search, compare periods, find averages, or spot trends.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Nocturne.palette.muted),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'TRY ASKING',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
            color: Nocturne.palette.muted,
          ),
        ),
        const SizedBox(height: 10),
        for (final p in _suggestedPrompts) ...[
          GestureDetector(
            onTap: () => _ask(p),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Nocturne.palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Nocturne.palette.edge),
              ),
              child: Row(
                children: [
                  Icon(PhRegular.chatCircleDots, size: 16, color: Nocturne.palette.accentMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(fontSize: 13, color: Nocturne.palette.text),
                    ),
                  ),
                  Icon(PhRegular.caretRight, size: 14, color: Nocturne.palette.faint),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (ctx, idx) {
        final m = _messages[idx];
        if (m.isUser) {
          return Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12, left: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Nocturne.palette.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                m.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Nocturne.palette.bg,
                ),
              ),
            ),
          );
        }

        final res = m.result;
        return Container(
          margin: const EdgeInsets.only(bottom: 16, right: 30),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Nocturne.palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Nocturne.palette.edge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(PhRegular.sparkle, size: 14, color: Nocturne.palette.accentMuted),
                  const SizedBox(width: 6),
                  Text(
                    'KinPurse AI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Nocturne.palette.accentMuted,
                    ),
                  ),
                  const Spacer(),
                  if (res?.error != null)
                    Icon(PhRegular.warning, size: 14, color: Nocturne.palette.expense),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                m.text,
                style: TextStyle(fontSize: 13.5, height: 1.4, color: Nocturne.palette.text),
              ),
              if (_assist(res?.query) case (final label, final run)) ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  key: const ValueKey('ask_assist_action'),
                  onPressed: run,
                  icon: const Icon(PhRegular.sparkle, size: 16),
                  label: Text(label),
                ),
              ],
              if (res != null && res.matchingTxns.isNotEmpty) ...[
                const SizedBox(height: 12),
                const V3RowDivider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Matching entries (${res.matchingTxns.length})',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: Nocturne.palette.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final t in res.matchingTxns.take(4)) ...[
                  GestureDetector(
                    onTap: () => V3Sheets.openDetail(context, t),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: Nocturne.palette.text),
                            ),
                          ),
                          Text(
                            V3Design.inr(t.amount),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Nocturne.palette.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (res.matchingTxns.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${res.matchingTxns.length - 4} more transactions',
                      style: TextStyle(fontSize: 11, color: Nocturne.palette.muted),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// The button under a 'help' answer: open a screen or switch a setting.
  (String, VoidCallback)? _assist(AskKinPurseQuery? q) {
    if (q == null || q.intent != 'help') return null;
    final nav = context.read<V3Nav>();
    final s = context.read<V3State>();
    final theme = context.read<ThemeController>();

    void done(String msg) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));

    if (q.setting case final key?) {
      final on = q.turnOn ?? true;
      final p = s.prefs;
      final (name, apply) = switch (key) {
        'app_lock' => ('App lock', () => s.savePrefs(p.copyWith(lockApp: on))),
        'hide_amounts' =>
          ('Hide amounts', () => s.savePrefs(p.copyWith(hideOnOpen: on))),
        'read_payments' =>
          ('Read payments', () => s.savePrefs(p.copyWith(smsAuto: on))),
        'prayer_times' => (
            'Prayer times',
            () => context.read<PrayerController>().setEnabled(on)
          ),
        'budget_alerts' =>
          ('Budget alerts', () => s.savePrefs(p.copyWith(budgetAlerts: on))),
        'family_alerts' =>
          ('Family activity alerts', () => s.savePrefs(p.copyWith(familyAlerts: on))),
        'approval_alerts' =>
          ('Approval alerts', () => s.savePrefs(p.copyWith(approvalAlerts: on))),
        'daily_digest' =>
          ('Daily digest', () => s.savePrefs(p.copyWith(dailyDigest: on))),
        'reduce_motion' =>
          ('Reduce motion', () async => theme.setReduceMotion(on)),
        _ => ('Match device theme', () async => theme.setMatchDevice(on)),
      };
      return (
        '${on ? 'Turn on' : 'Turn off'} $name',
        () async {
          await apply();
          done('$name ${on ? 'on' : 'off'}');
        }
      );
    }
    if (q.theme case final id?) {
      final t = KpThemeId.values.firstWhere((x) => x.id == id);
      return (
        'Use the ${t.name} theme',
        () {
          theme.setTheme(t);
          done('${t.name} theme on');
        }
      );
    }
    if (q.textSize case final size?) {
      final i = AskKinPurseEngine.textSizes.indexOf(size);
      return (
        'Make text $size',
        () {
          theme.setTextScale(ThemeController.textScales[i]);
          done('Text size changed');
        }
      );
    }
    final VoidCallback? open = switch (q.open) {
      'home' => () => nav.goTab(0),
      'activity' => () => nav.goTab(1),
      'insights' => () => nav.goTab(2),
      'more' => () => nav.goTab(3),
      'settings' => () => nav.goPage(V3Page.settings),
      'add' => () => V3Sheets.openAdd(context),
      'voice' => () => V3Sheets.openVoiceAdd(context),
      'detected' => () => nav.goPage(V3Page.detected),
      'cards' => () => nav.goPage(V3Page.cards),
      'notes' => () => nav.goPage(V3Page.notes),
      'messages' => () => nav.goPage(V3Page.chat),
      'notifications' => () => nav.goPage(V3Page.notifications),
      'prayer' => () => nav.goPage(V3Page.prayer),
      'prayer_settings' => () => nav.goPage(V3Page.prayerSettings),
      'ai_settings' => () => nav.goPage(V3Page.aiSettings),
      'monthly_recap' => () => nav.goPage(V3Page.monthlyRecap),
      'spending_calendar' => () => V3Sheets.openSpendingCalendar(context),
      'budget' => () => V3Sheets.openMagicAi(context),
      'goals' => () => V3Sheets.openGoals(context),
      'recurring' => () => V3Sheets.openRecurring(context),
      'categories' => () => CategoriesManagerV3.open(context),
      'money_sources' => () => SourcesManagerV3.open(context),
      'import' => () => ImportV3.open(context),
      'invite' => () => V3Sheets.openInvite(context),
      'faith' => () => V3Sheets.openFaithSuite(context),
      'guardian' => () => V3Sheets.openGuardian(context),
      'updates' => () => UpdateSheetV3.check(context),
      _ => null,
    };
    return open == null ? null : ('Take me there', open);
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Nocturne.palette.surface,
        border: Border(top: BorderSide(color: Nocturne.palette.edge)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: _ask,
              style: TextStyle(fontSize: 14, color: Nocturne.palette.text),
              decoration: InputDecoration(
                hintText: 'Ask about your money or the app…',
                hintStyle: TextStyle(fontSize: 13, color: Nocturne.palette.muted),
                filled: true,
                fillColor: Nocturne.palette.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _thinking ? null : () => _ask(_inputController.text),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _thinking ? Nocturne.palette.faint : Nocturne.palette.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhRegular.paperPlaneRight,
                size: 18,
                color: Nocturne.palette.bg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

