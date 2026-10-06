import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/update_service.dart';
import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../sheets/update_sheet_v3.dart';
import '../widgets/v3_motion.dart';

/// Sign in / sign up.
///
/// Credentials go straight to Supabase and the result is checked: a failure
/// surfaces as an error rather than falling through to a signed-in state.
class AuthV3 extends StatefulWidget {
  final VoidCallback onSignedIn;
  const AuthV3({super.key, required this.onSignedIn});

  @override
  State<AuthV3> createState() => _AuthV3State();
}

class _AuthV3State extends State<AuthV3> {
  bool _signUp = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (!email.contains('@') || email.length < 5) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Passwords must be at least 6 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      if (_signUp) {
        final res = await auth.signUp(
          email: email,
          password: password,
          data: {'full_name': _name.text.trim()},
        );
        if (res.user == null) {
          throw const AuthException('Sign up did not complete.');
        }
      } else {
        final res = await auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (res.user == null) {
          throw const AuthException('Incorrect email or password.');
        }
      }
      if (!mounted) return;
      widget.onSignedIn();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not reach the server. Check your connection.';
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
          child: Stack(
            children: [
              // Updating has to be reachable without signing in: someone on an
              // old build may be unable to get past this screen, and settings
              // sit behind the sign-in.
              Positioned(
                top: 4,
                right: 4,
                child: V3Press(
                  onTap: () => UpdateSheetV3.check(context),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'v${UpdateService.currentVersion}',
                          style: const TextStyle(
                              fontSize: 11.5, color: Nocturne.neutral500),
                        ),
                        const SizedBox(width: 6),
                        const Icon(PhRegular.gear,
                            size: 18, color: Nocturne.neutral400),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
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
                  const Text('Collaborative finances for your household',
                      style: TextStyle(
                          fontSize: 13, color: Nocturne.neutral500)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Nocturne.surface,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        for (final o in const [
                          (false, 'Sign in'),
                          (true, 'Create account'),
                        ])
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _signUp = o.$1;
                                _error = null;
                              }),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _signUp == o.$1
                                      ? Nocturne.accent900
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _signUp == o.$1
                                        ? Nocturne.accent600
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Text(o.$2,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _signUp == o.$1
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
                  if (_signUp) ...[
                    _Input(
                      controller: _name,
                      icon: PhRegular.user,
                      hint: 'Your name',
                    ),
                    const SizedBox(height: 10),
                  ],
                  _Input(
                    controller: _email,
                    icon: PhRegular.envelopeSimple,
                    hint: 'Email address',
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _Input(
                    controller: _password,
                    icon: PhRegular.lockSimple,
                    hint: 'Password',
                    obscure: _obscure,
                    trailing: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                          _obscure ? PhRegular.eye : PhRegular.eyeSlash,
                          size: 18,
                          color: Nocturne.neutral500),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
                                  strokeWidth: 2, color: Nocturne.accent100),
                            )
                          : Text(_signUp ? 'Create account' : 'Sign in',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Nocturne.accent100)),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? trailing;

  const _Input({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Nocturne.neutral800, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Nocturne.neutral500),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboard,
                autocorrect: false,
                style: const TextStyle(fontSize: 15, color: Nocturne.text),
                cursorColor: Nocturne.accent,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: const TextStyle(
                      fontSize: 15, color: Nocturne.neutral600),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}
