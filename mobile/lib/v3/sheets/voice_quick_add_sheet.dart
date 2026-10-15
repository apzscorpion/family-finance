import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/voice_service.dart';
import '../../theme/nocturne.dart';
import '../data/pending_quick_add.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import 'v3_sheets.dart';

/// Modal bottom sheet for voice expense entry.
/// Prompts speech recognition and parses input via [QuickAddParser].
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
  bool _isListening = false;
  String _transcript = '';
  PendingQuickAdd? _parsed;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceInput();
    });
  }

  Future<void> _startVoiceInput() async {
    setState(() {
      _isListening = true;
      _errorMessage = null;
    });

    final text = await VoiceService.promptVoiceInput();

    if (!mounted) return;

    if (text == null || text.trim().isEmpty) {
      setState(() {
        _isListening = false;
        _errorMessage = 'No voice input heard. Tap the microphone to try again.';
      });
      return;
    }

    final parsed = QuickAddParser.parse(text);

    setState(() {
      _isListening = false;
      _transcript = text;
      _parsed = parsed;
      if (parsed == null) {
        _errorMessage = "Couldn't detect an amount from \"$text\". Tap to edit or retry.";
      }
    });
  }

  Future<void> _saveEntry() async {
    if (_parsed == null) return;
    final s = context.read<V3State>();

    final ok = await s.addTransaction(
      title: _parsed!.title,
      amount: _parsed!.amount,
      type: 'expense',
      categoryKey: _parsed!.categoryKey ?? 'groceries',
      method: 'UPI',
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${V3Design.inr(_parsed!.amount)} for ${_parsed!.title}'),
          backgroundColor: Nocturne.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'Could not save expense. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final parsed = _parsed;
    final cat = parsed?.categoryKey != null ? s.catStyle(parsed!.categoryKey!) : null;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.neutral800, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Nocturne.neutral700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              const Icon(PhFill.sparkle, size: 20, color: Nocturne.accent300),
              const SizedBox(width: 8),
              const Text(
                'Voice Quick Add',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.text,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(PhRegular.x, size: 20, color: Nocturne.neutral400),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Speech animated mic button
          GestureDetector(
            onTap: _isListening ? null : _startVoiceInput,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isListening
                      ? [Nocturne.accent, const Color(0xFF9333EA)]
                      : [Nocturne.neutral800, Nocturne.neutral900],
                ),
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: Nocturne.accent.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                PhBold.sparkle,
                size: 32,
                color: _isListening ? Colors.white : Nocturne.neutral300,
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            _isListening
                ? 'Listening… speak an amount & merchant'
                : (_transcript.isEmpty ? 'Tap to speak' : 'You said:'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Nocturne.neutral400,
            ),
          ),

          if (_transcript.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Nocturne.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: Text(
                '"$_transcript"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Nocturne.text,
                ),
              ),
            ),
          ],

          if (parsed != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Nocturne.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Nocturne.accent600.withValues(alpha: 0.5), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cat?.color.withValues(alpha: 0.15) ?? Nocturne.neutral800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      cat?.icon ?? PhRegular.shoppingBag,
                      color: cat?.color ?? Nocturne.accent300,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsed.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Nocturne.text,
                          ),
                        ),
                        Text(
                          cat?.name ?? 'Groceries',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Nocturne.neutral400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    V3Design.inr(parsed.amount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Nocturne.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      V3Sheets.openAdd(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Nocturne.neutral300,
                      side: const BorderSide(color: Nocturne.neutral800),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Edit manually'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Nocturne.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirm & Save'),
                  ),
                ),
              ],
            ),
          ] else if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: NocturneSemantic.warning,
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Text(
            'Tip: Say something like "450 petrol HDFC" or "₹1200 groceries"',
            style: TextStyle(
              fontSize: 11,
              color: Nocturne.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}

