import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../v3_state.dart';

/// Shown when the signed-in user belongs to no family yet: create one, or join
/// an existing workspace with its code.
class OnboardingV3 extends StatefulWidget {
  const OnboardingV3({super.key});

  @override
  State<OnboardingV3> createState() => _OnboardingV3State();
}

class _OnboardingV3State extends State<OnboardingV3> {
  bool _joining = false;
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.read<V3State>();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_joining) {
        final code = _code.text.trim();
        if (code.length < 6) {
          setState(() {
            _busy = false;
            _error = 'Enter the 8-character workspace code.';
          });
          return;
        }
        await s.repo.joinByCode(code);
      } else {
        final name = _name.text.trim();
        if (name.isEmpty) {
          setState(() {
            _busy = false;
            _error = 'Give your workspace a name.';
          });
          return;
        }
        await s.repo.createFamily(name);
      }
      await s.bootstrap();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _joining
            ? 'That code did not match a workspace.'
            : 'Could not create the workspace. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Nocturne.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.1,
            colors: [Color(0xFF1F2236), Nocturne.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Nocturne.accent500, Nocturne.accent800],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Nocturne.mix(Nocturne.accent, 40),
                            blurRadius: 28),
                      ],
                    ),
                    child: const Icon(PhRegular.wallet,
                        size: 30, color: Nocturne.accent100),
                  ),
                  const SizedBox(height: 18),
                  const Text('Family Spend Tracker',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Nocturne.text)),
                  const SizedBox(height: 6),
                  const Text(
                      'Create a workspace for your household, or join one '
                      'with its code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Nocturne.neutral500)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Nocturne.surface,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        for (final o in const [(false, 'Create'), (true, 'Join')])
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _joining = o.$1;
                                _error = null;
                              }),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _joining == o.$1
                                      ? Nocturne.accent900
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _joining == o.$1
                                        ? Nocturne.accent600
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Text(o.$2,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _joining == o.$1
                                          ? Nocturne.accent100
                                          : Nocturne.neutral400,
                                    )),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Nocturne.surface,
                      borderRadius: BorderRadius.circular(13),
                      border:
                          Border.all(color: Nocturne.neutral800, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(_joining ? PhRegular.link : PhRegular.users,
                            size: 18, color: Nocturne.neutral500),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _joining ? _code : _name,
                            textCapitalization: _joining
                                ? TextCapitalization.characters
                                : TextCapitalization.words,
                            style: TextStyle(
                              fontSize: 15,
                              color: Nocturne.text,
                              letterSpacing: _joining ? 2 : 0,
                            ),
                            cursorColor: Nocturne.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: _joining
                                  ? 'Workspace code'
                                  : "e.g. Khan Family",
                              hintStyle: const TextStyle(
                                  fontSize: 15,
                                  letterSpacing: 0,
                                  color: Nocturne.neutral600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Nocturne.mix(NocturneSemantic.expense, 12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Nocturne.mix(NocturneSemantic.expense, 50),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(PhRegular.warning,
                              size: 16, color: NocturneSemantic.expense),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: NocturneSemantic.expense)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _busy ? null : _submit,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Nocturne.mix(Nocturne.accent, 18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Nocturne.accent, width: 1),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Nocturne.accent100),
                            )
                          : Text(
                              _joining ? 'Join workspace' : 'Create workspace',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Nocturne.accent100),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
