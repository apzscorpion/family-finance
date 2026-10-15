import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../v3_state.dart';
import '../widgets/kinpurse_wordmark.dart';

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
      backgroundColor: Nocturne.palette.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.1,
            colors: [Nocturne.palette.tint, Nocturne.palette.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/branding/kinpurse.png',
                        width: 88, height: 88, semanticLabel: 'KinPurse'),
                  ),
                  const SizedBox(height: 18),
                  const KinPurseWordmark(size: 28),
                  const SizedBox(height: 6),
                  Text(
                      'Create a workspace for your household, or join one '
                      'with its code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Nocturne.palette.muted)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Nocturne.palette.surface,
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
                                      ? Nocturne.palette.tint
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _joining == o.$1
                                        ? Nocturne.palette.tintEdge
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Text(o.$2,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _joining == o.$1
                                          ? Nocturne.palette.accentLight
                                          : Nocturne.palette.subtle,
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
                      color: Nocturne.palette.surface,
                      borderRadius: BorderRadius.circular(13),
                      border:
                          Border.all(color: Nocturne.palette.edge, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(_joining ? PhRegular.link : PhRegular.users,
                            size: 18, color: Nocturne.palette.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _joining ? _code : _name,
                            textCapitalization: _joining
                                ? TextCapitalization.characters
                                : TextCapitalization.words,
                            style: TextStyle(
                              fontSize: 15,
                              color: Nocturne.palette.text,
                              letterSpacing: _joining ? 2 : 0,
                            ),
                            cursorColor: Nocturne.palette.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: _joining
                                  ? 'Workspace code'
                                  : "e.g. Khan Family",
                              hintStyle: TextStyle(
                                  fontSize: 15,
                                  letterSpacing: 0,
                                  color: Nocturne.palette.faint),
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
                        color: Nocturne.mix(Nocturne.palette.expense, 12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Nocturne.mix(Nocturne.palette.expense, 50),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(PhRegular.warning,
                              size: 16, color: Nocturne.palette.expense),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Nocturne.palette.expense)),
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
                        color: Nocturne.mix(Nocturne.palette.accent, 18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Nocturne.palette.accent, width: 1),
                      ),
                      child: _busy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Nocturne.palette.accentLight),
                            )
                          : Text(
                              _joining ? 'Join workspace' : 'Create workspace',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Nocturne.palette.accentLight),
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
