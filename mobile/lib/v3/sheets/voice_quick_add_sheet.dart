import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../services/app_log.dart';
import '../../services/voice_service.dart';
import '../../theme/nocturne.dart';
import '../data/ai/ai_config.dart';
import '../data/ai/ask_kinpurse_engine.dart';
import '../data/ai/voice_assistant.dart';
import '../data/pending_quick_add.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import 'v3_sheets.dart';

enum _Phase { idle, listening, thinking, speaking }

/// Voice assistant sheet: a hands-free loop of listen → think → speak →
/// listen, until the user taps stop, says "bye" or dismisses the speech
/// dialog. A bare "450 petrol HDFC" is parsed on the device; anything else goes
/// to the user's AI provider. Without one it only does quick expenses.
class VoiceQuickAddSheet extends StatefulWidget {
  const VoiceQuickAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => const VoiceQuickAddSheet(),
    );
  }

  @override
  State<VoiceQuickAddSheet> createState() => _VoiceQuickAddSheetState();
}

class _VoiceQuickAddSheetState extends State<VoiceQuickAddSheet> {
  final _tts = FlutterTts();
  final _scroll = ScrollController();

  /// (fromUser, text), oldest first.
  final _messages = <(bool, String)>[];
  _Phase _phase = _Phase.idle;
  bool _running = false;
  AiConfig _config = const AiConfig();

  /// An add waiting for yes or no.
  VoiceAction? _pending;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (err) {
      AppLog.error('VoiceSheet.tts', err);
    }
    _config = await AiConfigStore.load();
    if (!mounted) return;
    if (!_config.isConfigured) {
      _add(false,
          'Say an expense like "450 petrol HDFC". To chat with me, add an AI key in Settings → AI.');
    }
    _loop();
  }

  @override
  void dispose() {
    _running = false;
    _tts.stop();
    _scroll.dispose();
    super.dispose();
  }

  void _add(bool fromUser, String text) {
    setState(() => _messages.add((fromUser, text)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _setPhase(_Phase p) {
    if (mounted) setState(() => _phase = p);
  }

  Future<void> _loop() async {
    if (_running) return;
    _running = true;
    while (_running && mounted) {
      _setPhase(_Phase.listening);
      final text = await VoiceService.promptVoiceInput(
        prompt: _pending != null ? 'Say yes or no' : 'Listening…',
      );
      if (!mounted || !_running) break;
      // Dismissed or silence: end the loop rather than reopen the dialog.
      if (text == null) break;
      _add(true, text);
      if (!await _handle(text)) break;
    }
    _running = false;
    _setPhase(_Phase.idle);
  }

  void _stop() {
    _running = false;
    _tts.stop();
    _setPhase(_Phase.idle);
  }

  Future<void> _say(String text) async {
    if (!mounted) return;
    _add(false, text);
    if (!_running) return;
    _setPhase(_Phase.speaking);
    try {
      await _tts.speak(VoiceAssistant.forSpeech(text));
    } catch (err) {
      AppLog.error('VoiceSheet.speak', err);
    }
  }

  /// One user utterance. Returns false to end the conversation.
  Future<bool> _handle(String text) async {
    if (VoiceAssistant.isStop(text)) {
      _pending = null;
      await _say('Bye! Talk soon.');
      return false;
    }
    final pending = _pending;
    if (pending != null) {
      if (VoiceAssistant.isNo(text)) {
        setState(() => _pending = null);
        await _say('Okay, cancelled.');
        return true;
      }
      if (VoiceAssistant.isYes(text)) {
        await _save(pending);
        return true;
      }
      // Anything else is a new request.
      setState(() => _pending = null);
    }

    if (!mounted) return false;
    final s = context.read<V3State>();
    final quick = VoiceAssistant.quickExpense(text);
    if (quick != null) {
      await _propose(_fromQuick(quick, text, s));
      return true;
    }
    if (!_config.isConfigured) {
      await _say(
          'Without an AI key I can only add expenses, like "450 petrol". Add one in Settings → AI to chat with me.');
      return true;
    }

    _setPhase(_Phase.thinking);
    final res = await VoiceAssistant.chat(
      config: _config,
      userText: text,
      history: [
        // The latest user line is sent separately.
        for (final (fromUser, t) in _messages.take(_messages.length - 1))
          (fromUser ? 'User' : 'Assistant', t),
      ],
      categories: [for (final c in s.categories) c.name],
      accounts: [for (final a in s.mySources) a.name],
      myName: s.me?.name ?? '',
    );
    if (!mounted || !_running) return false;
    final turn = res.turn;
    if (turn == null) {
      AppLog.error('VoiceSheet.chat', res.error ?? 'no reply');
      if (res.error != null) _add(false, res.error!);
      await _say('Sorry, something went wrong with the AI. Tap the mic to try again.');
      return false;
    }

    final action = turn.action;
    if (action == null) {
      await _say(turn.reply);
    } else if (action.isAdd) {
      await _propose(action);
    } else {
      if (turn.reply.isNotEmpty) await _say(turn.reply);
      if (!_running) return false;
      _setPhase(_Phase.thinking);
      final answer = await AskKinPurseEngine.ask(
        question: action.question!,
        config: _config,
        txns: s.txns,
        categories: s.categories,
        members: s.members,
        myName: s.me?.name ?? '',
      );
      await _say(answer.error != null
          ? 'Sorry, I couldn’t work that out.'
          : answer.answerText.replaceAll('\n', ' '));
    }
    return true;
  }

  VoiceAction _fromQuick(PendingQuickAdd q, String text, V3State s) {
    final account = VoiceAssistant.matchAccount(
        text, [for (final a in s.mySources) a.name]);
    var title = q.title;
    if (account != null) {
      title = title
          .replaceAll(RegExp(RegExp.escape(account), caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);
    }
    return VoiceAction(
      type: 'add_expense',
      amount: q.amount,
      title: title.isEmpty ? 'Quick add' : title,
      category: q.categoryKey,
      account: account,
    );
  }

  Future<void> _propose(VoiceAction a) async {
    setState(() => _pending = a);
    final src = _source(a.account);
    final what = a.title ?? (a.isIncome ? 'income' : 'expense');
    await _say(a.isIncome
        ? 'Add income of ${V3Design.inr(a.amount!)} for $what${src == null ? '' : ' to ${src.name}'}?'
        : 'Add ${V3Design.inr(a.amount!)} $what${src == null ? '' : ' from ${src.name}'}?');
  }

  SourceRow? _source(String? name) {
    if (name == null) return null;
    final s = context.read<V3State>();
    final match = VoiceAssistant.matchAccount(
        name, [for (final a in s.mySources) a.name]);
    for (final a in s.mySources) {
      final n = a.name.toLowerCase();
      if (a.name == match || n == name.toLowerCase() || n.contains(name.toLowerCase())) {
        return a;
      }
    }
    return null;
  }

  String _categoryKey(VoiceAction a, V3State s) {
    final kind = a.isIncome ? 'income' : 'expense';
    final cats = [for (final c in s.categories) if (c.kind == kind) c];
    final q = a.category?.toLowerCase();
    if (q != null) {
      for (final c in cats) {
        if (c.key == q || c.name.toLowerCase() == q) return c.key;
      }
      for (final c in cats) {
        final n = c.name.toLowerCase();
        if (n.contains(q) || q.contains(n)) return c.key;
      }
    }
    final guess = QuickAddParser.categoryFor('${a.title ?? ''} ${a.category ?? ''}');
    if (!a.isIncome && guess != null) return guess;
    if (a.isIncome) return cats.isEmpty ? 'salary' : cats.first.key;
    // The old quick add filed unknowns under groceries; keep that.
    return 'groceries';
  }

  Future<void> _save(VoiceAction a) async {
    final s = context.read<V3State>();
    setState(() => _pending = null);
    final ok = await s.addTransaction(
      title: a.title ?? '',
      amount: a.amount!,
      type: a.isIncome ? 'income' : 'expense',
      categoryKey: _categoryKey(a, s),
      method: 'UPI',
      sourceId: _source(a.account)?.id,
    );
    if (!mounted) return;
    await _say(ok
        ? 'Done. Added ${V3Design.inr(a.amount!)} for ${a.title ?? 'that'}.'
        : 'Sorry, I couldn’t save that. Check your connection.');
  }

  /// Yes or No tapped while the loop is stopped.
  Future<void> _answerTapped(bool yes) async {
    final p = _pending;
    if (p == null) return;
    if (yes) {
      await _save(p);
    } else {
      setState(() => _pending = null);
      _add(false, 'Okay, cancelled.');
    }
  }

  String get _status => switch (_phase) {
        _Phase.listening => 'Listening…',
        _Phase.thinking => 'Thinking…',
        _Phase.speaking => 'Speaking…',
        _Phase.idle => _messages.isEmpty ? 'Tap the mic to talk' : 'Tap the mic to continue',
      };

  @override
  Widget build(BuildContext context) {
    final p = Nocturne.palette;
    final pending = _pending;
    final active = _phase != _Phase.idle;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: p.edge, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: p.faint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(PhFill.sparkle, size: 20, color: p.accentMuted),
              const SizedBox(width: 8),
              Text(
                'Voice assistant',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                icon: Icon(PhRegular.x, size: 20, color: p.subtle),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_messages.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: ListView.builder(
                controller: _scroll,
                shrinkWrap: true,
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final (fromUser, text) = _messages[i];
                  return Align(
                    alignment:
                        fromUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: fromUser ? p.tint : p.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: fromUser ? p.tintEdge : p.edge,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(fontSize: 14, color: p.text),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (pending != null && !_running) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      V3Sheets.openAdd(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.neutral300,
                      side: BorderSide(color: p.edge),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _answerTapped(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.neutral300,
                      side: BorderSide(color: p.edge),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _answerTapped(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.fab,
                      foregroundColor: p.fabIcon,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Yes, save'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (active)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.accent,
                  ),
                ),
              if (active) const SizedBox(width: 8),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: p.subtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: _running ? 'Stop' : 'Talk',
            child: GestureDetector(
              onTap: _running ? _stop : _loop,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _running ? p.expense : p.fab,
                  border: Border.all(color: p.fabEdge, width: 1),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: p.glow,
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _running ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 32,
                  color: p.fabIcon,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Try "450 petrol HDFC", "how much on food this month?" or "bye"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: p.faint),
          ),
        ],
      ),
    );
  }
}
