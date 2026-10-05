import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/finance_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../services/app_log.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  bool _isSignUp = false;
  bool _joinExistingFamily = false;

  // Email verification OTP step (only shown when verifying email on registration)
  bool _awaitingOtpStep = false;
  String _activeIdentifier = '';
  String _targetFamilyCode = '';
  String _resolvedFullName = '';
  String _resolvedFamilyName = '';
  bool _isJoiningExistingGroup = false;
  String? _autoReadStatusMsg;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  final _familyCodeCtrl = TextEditingController();
  final _loginOtpCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMsg;
  late String _generatedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generatedCode = FinanceProvider.generateUniqueFamilyCode();
    _nameCtrl.addListener(_refreshPreviewCode);
    _emailCtrl.addListener(_refreshPreviewCode);
  }

  void _refreshPreviewCode() {
    final email = _emailCtrl.text.trim().toLowerCase();
    final name = _nameCtrl.text.trim();
    if (email.isNotEmpty || name.isNotEmpty) {
      final deterministic = SupabaseService.deriveDeterministicOwnerCode(
        email.isNotEmpty ? email : name,
        fullName: name,
      );
      if (deterministic != _generatedCode && mounted) {
        setState(() {
          _generatedCode = deterministic;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameCtrl.removeListener(_refreshPreviewCode);
    _emailCtrl.removeListener(_refreshPreviewCode);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _familyCtrl.dispose();
    _familyCodeCtrl.dispose();
    _loginOtpCtrl.dispose();
    super.dispose();
  }

  /// Auto-read 6-digit OTP when returning from Email app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingOtpStep) {
      _tryAutoReadOtpFromClipboard(silentIfEmpty: true);
    }
  }

  Future<void> _tryAutoReadOtpFromClipboard({bool silentIfEmpty = false}) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text?.trim() ?? '';
      final extracted = SupabaseService.extractOtpFromText(raw);
      if (extracted != null && extracted.length == 6) {
        if (!mounted) return;
        setState(() {
          if (_loginOtpCtrl.text.trim().isEmpty || !silentIfEmpty) {
            _loginOtpCtrl.text = extracted;
            _autoReadStatusMsg = 'Pasted 6-digit verification code from clipboard';
          }
          _errorMsg = null;
        });
      } else if (!silentIfEmpty && mounted) {
        setState(() {
          _errorMsg = 'No 6-digit verification code found in clipboard.';
        });
      }
    } catch (err, errStack) {
      AppLog.error('AuthScreen._tryAutoReadOtpFromClipboard', err, errStack);
    }
  }

  Future<void> _handlePrimaryAuthAction(FinanceProvider provider) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
      _autoReadStatusMsg = null;
    });

    final rawEmail = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();

    if (rawEmail.isEmpty || !rawEmail.contains('@')) {
      setState(() {
        _loading = false;
        _errorMsg = 'Please enter a valid Email Address.';
      });
      return;
    }

    if (pass.isEmpty || pass.length < 4) {
      setState(() {
        _loading = false;
        _errorMsg = 'Please enter your password.';
      });
      return;
    }

    try {
      String manualCode = _familyCodeCtrl.text.trim().toUpperCase();
      final rawFamInput = _familyCtrl.text.trim();

      // Safety net: if user pasted an invite code like "NTY5AFLR" into the Family Name box by mistake
      if (manualCode.isEmpty &&
          rawFamInput.length >= 6 &&
          rawFamInput.length <= 8 &&
          RegExp(r'^[A-Za-z0-9]{6,8}$').hasMatch(rawFamInput) &&
          RegExp(r'[0-9]').hasMatch(rawFamInput)) {
        manualCode = rawFamInput.toUpperCase();
        _familyCodeCtrl.text = manualCode;
        _joinExistingFamily = true;
      }

      final defaultName = rawEmail.split('@')[0];
      final enteredName = _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : defaultName;

      if (_isSignUp && _joinExistingFamily && manualCode.length < 6) {
        setState(() {
          _loading = false;
          _errorMsg = 'Please enter a valid 6–8 character Family Invite Code (e.g. NTY5AFLR).';
        });
        return;
      }

      final localAcct = await SupabaseService.getLocalAccount(rawEmail);
      if (!_isSignUp && localAcct != null && localAcct.hasPassword && !localAcct.verifyPassword(pass)) {
        setState(() {
          _loading = false;
          _errorMsg = 'Incorrect password for $rawEmail.';
        });
        return;
      }

      // Check cloud metadata if signing in
      String? cloudFamilyCode;
      String? cloudFamilyName;
      String? cloudFullName;
      bool? cloudIsOwner;
      if (!_isSignUp) {
        try {
          final outcome =
              await SupabaseService.signInDetailed(email: rawEmail, password: pass);

          // The server actively rejected these credentials -> never log in.
          if (outcome.isRejected) {
            setState(() {
              _loading = false;
              _errorMsg = outcome.message?.isNotEmpty == true
                  ? outcome.message
                  : 'Incorrect email or password.';
            });
            return;
          }

          // Cloud unreachable: only allow an offline login for an account that
          // already exists on this device AND whose stored password matches.
          if (outcome.status == SignInStatus.cloudUnavailable) {
            if (localAcct == null || !localAcct.hasPassword || !localAcct.verifyPassword(pass)) {
              setState(() {
                _loading = false;
                _errorMsg =
                    'Could not reach the server. Connect to the internet to sign in to this account.';
              });
              return;
            }
          }

          final meta = outcome.response?.user?.userMetadata;
          if (meta != null) {
            final cCode = meta['family_code']?.toString().trim().toUpperCase();
            if (cCode != null && cCode.length >= 6 && cCode != '38DJPUZ6' && cCode != 'MKSN3DGQ') {
              cloudFamilyCode = cCode;
            }
            final cFam = meta['family_name']?.toString().trim();
            if (cFam != null && cFam.isNotEmpty && !cFam.contains('Tester Abhi')) {
              cloudFamilyName = cFam;
            }
            final cName = meta['full_name']?.toString().trim();
            if (cName != null && cName.isNotEmpty && !cName.contains('Tester Abhi')) {
              cloudFullName = cName;
            }
            if (meta['is_owner'] is bool) cloudIsOwner = meta['is_owner'] as bool;
          }
        } catch (e) {
          // Never fall through to a successful login on an unexpected auth error.
          setState(() {
            _loading = false;
            _errorMsg = 'Could not sign in right now. Please try again.';
          });
          return;
        }
      }

      String resolvedName = (!_isSignUp && (cloudFullName?.isNotEmpty == true))
          ? cloudFullName!
          : ((!_isSignUp && localAcct?.fullName.isNotEmpty == true && !localAcct!.fullName.contains('Tester Abhi'))
              ? localAcct.fullName
              : enteredName);

      if (SupabaseService.ownerLegacyCodes.containsKey(rawEmail)) {
        if (resolvedName.toLowerCase().contains('tester') || resolvedName.toLowerCase() == 'apzscorpion') {
          resolvedName = 'Asif';
        }
      }

      final deterministicOwnerCode = SupabaseService.deriveDeterministicOwnerCode(
        rawEmail,
        fullName: resolvedName,
      );

      final bool joiningByCode = (_isSignUp && _joinExistingFamily) ||
          (manualCode.length >= 6 && manualCode != deterministicOwnerCode);

      String targetCode;
      if (joiningByCode && manualCode.length >= 6) {
        targetCode = manualCode;
      } else if (SupabaseService.ownerLegacyCodes.containsKey(rawEmail)) {
        targetCode = SupabaseService.ownerLegacyCodes[rawEmail]!;
      } else if (_isSignUp) {
        targetCode = deterministicOwnerCode;
      } else {
        targetCode = (cloudFamilyCode != null && cloudFamilyCode.length >= 6)
            ? cloudFamilyCode
            : ((localAcct?.familyCode.isNotEmpty == true &&
                    localAcct!.familyCode.length >= 6 &&
                    localAcct.familyCode != '38DJPUZ6' &&
                    localAcct.familyCode != 'MKSN3DGQ')
                ? localAcct.familyCode
                : deterministicOwnerCode);
      }

      final bool isOwnerOfTarget = !joiningByCode &&
          (targetCode == deterministicOwnerCode || (cloudIsOwner ?? localAcct?.isOwner ?? true));

      String resolvedFamName;
      if (!isOwnerOfTarget) {
        if (targetCode == 'NTY5AFLR') {
          resolvedFamName = "Asif's Family";
        } else if (cloudFamilyName != null && cloudFamilyName.isNotEmpty && cloudFamilyCode == targetCode) {
          resolvedFamName = cloudFamilyName;
        } else if (localAcct != null && localAcct.familyCode == targetCode && localAcct.familyName.isNotEmpty) {
          resolvedFamName = localAcct.familyName;
        } else {
          resolvedFamName = 'Family ($targetCode)';
        }
      } else {
        final enteredFamName = (rawFamInput.isNotEmpty && rawFamInput.toUpperCase() != targetCode)
            ? rawFamInput
            : "$resolvedName's Family";
        resolvedFamName = (!_isSignUp && (cloudFamilyName?.isNotEmpty == true))
            ? cloudFamilyName!
            : ((!_isSignUp && localAcct?.familyName.isNotEmpty == true && !localAcct!.familyName.contains('Tester Abhi'))
                ? localAcct.familyName
                : enteredFamName);
      }

      // Check if disabled in this family
      final isDisabled = await SupabaseService.isUserDisabledInFamily(
        email: rawEmail,
        name: resolvedName,
        familyCode: targetCode,
      );
      if (isDisabled) {
        setState(() {
          _loading = false;
          _errorMsg = 'Your access to family workspace ($targetCode) has been disabled by the Family Owner.';
        });
        return;
      }

      // SIGN IN: Complete login directly without asking for OTP again!
      if (!_isSignUp) {
        final saved = await SupabaseService.saveLocalAccount(
          email: rawEmail,
          password: pass,
          fullName: resolvedName,
          familyName: resolvedFamName,
          familyCode: targetCode,
          isOwner: isOwnerOfTarget,
        );

        await provider.setLoggedIn(
          true,
          userName: saved.fullName,
          userKey: rawEmail,
          familyName: saved.familyName,
          familyCode: saved.familyCode,
          isOwner: isOwnerOfTarget,
        );

        if (mounted) {
          setState(() => _loading = false);
          provider.showToast('Welcome, ${saved.fullName} · ${provider.familyName} (${provider.familyCode})');
        }
        return;
      }

      // CREATE ACCOUNT: Send verification OTP to user's email via Supabase Auth
      await SupabaseService.generateLoginOtp(rawEmail);
      await SupabaseService.signUp(
        email: rawEmail,
        password: pass,
        fullName: resolvedName,
        familyName: resolvedFamName,
        familyCode: targetCode,
        isOwner: isOwnerOfTarget,
      );

      setState(() {
        _activeIdentifier = rawEmail;
        _targetFamilyCode = targetCode;
        _resolvedFullName = resolvedName;
        _resolvedFamilyName = resolvedFamName;
        _isJoiningExistingGroup = !isOwnerOfTarget;
        _loginOtpCtrl.clear();
        _awaitingOtpStep = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// Verify Email OTP on account creation and complete sign-up
  Future<void> _verifyAndCompleteAuth(FinanceProvider provider) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final identifier = _activeIdentifier;
    final pass = _passCtrl.text.trim();
    final extractedOtp = SupabaseService.extractOtpFromText(_loginOtpCtrl.text) ?? _loginOtpCtrl.text.trim();

    if (extractedOtp.length != 6) {
      setState(() {
        _loading = false;
        _errorMsg = 'Please enter the 6-digit verification code sent to $_activeIdentifier.';
      });
      return;
    }

    try {
      final otpValid = await SupabaseService.verifyLoginOtp(identifier, extractedOtp);
      if (!otpValid) {
        setState(() {
          _loading = false;
          _errorMsg = 'Invalid or expired 6-digit verification code. Please check your email and try again.';
        });
        return;
      }

      final bool isOwner = !_isJoiningExistingGroup;
      final localRecord = await SupabaseService.saveLocalAccount(
        email: identifier,
        password: pass,
        fullName: _resolvedFullName,
        familyName: _resolvedFamilyName,
        familyCode: _targetFamilyCode,
        isOwner: isOwner,
      );

      await provider.setLoggedIn(
        true,
        userName: localRecord.fullName,
        userKey: identifier,
        familyName: localRecord.familyName,
        familyCode: localRecord.familyCode,
        isOwner: isOwner,
        clearWorkspaceOnNewAccount: isOwner,
      );

      if (mounted) {
        provider.showToast('Email verified! Welcome to ${provider.familyName} (${provider.familyCode})');
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendEmailOtp() async {
    if (_activeIdentifier.isEmpty) return;
    await SupabaseService.generateLoginOtp(_activeIdentifier);
    if (SupabaseService.isConfigured) {
      try {
        await SupabaseService.client.auth.resend(
          type: OtpType.signup,
          email: _activeIdentifier,
        );
      } catch (err, errStack) {
        AppLog.error('AuthScreen._resendEmailOtp', err, errStack);
      }
    }
    if (mounted) {
      setState(() {
        _autoReadStatusMsg = 'Verification code resent to $_activeIdentifier';
        _errorMsg = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent500, AppTheme.accent800],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Family Spend Tracker',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              const Text(
                'Collaborative finances for your family & friends groups',
                style: TextStyle(fontSize: 13, color: AppTheme.textSubtle),
              ),
              const SizedBox(height: 28),

              // Auth Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF3F424D)),
                  boxShadow: const [AppTheme.shadowMd],
                ),
                child: _awaitingOtpStep
                    ? _buildOtpVerificationStep(provider)
                    : _buildCredentialsStep(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialsStep(FinanceProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Sign In vs Create Account
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isSignUp = false;
                    _errorMsg = null;
                  }),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: !_isSignUp ? AppTheme.accent900 : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: !_isSignUp ? AppTheme.accent : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: !_isSignUp ? AppTheme.accent100 : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isSignUp = true;
                    _errorMsg = null;
                  }),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isSignUp ? AppTheme.accent900 : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _isSignUp ? AppTheme.accent : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _isSignUp ? AppTheme.accent100 : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (_isSignUp) ...[
          _buildTextField(_nameCtrl, 'Your Full Name (e.g. Asif)', Icons.person_outline),
          const SizedBox(height: 12),

          // Choice: Create new family vs Join via code
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _joinExistingFamily = false;
                      _familyCodeCtrl.clear();
                    }),
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: !_joinExistingFamily ? AppTheme.accent800 : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Create My Family',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: !_joinExistingFamily ? Colors.white : AppTheme.textMuted),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _joinExistingFamily = true),
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: _joinExistingFamily ? AppTheme.accent800 : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Join Family by Code',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _joinExistingFamily ? Colors.white : AppTheme.textMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (!_joinExistingFamily) ...[
            _buildTextField(_familyCtrl, "Your Family Name (e.g. Asif's Family)", Icons.people_outline),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.key, size: 14, color: AppTheme.accent300),
                  const SizedBox(width: 8),
                  const Text('Your Family Invite Code: ', style: TextStyle(fontSize: 11.5, color: AppTheme.textSubtle)),
                  Text(
                    _generatedCode,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.accent100, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildTextField(
              _familyCodeCtrl,
              'Enter 6–8 digit Family Invite Code (e.g. NTY5AFLR)',
              Icons.vpn_key_outlined,
              keyboardType: TextInputType.text,
            ),
          ],
          const SizedBox(height: 12),
        ],

        // Single Email field + Single Password field
        _buildTextField(
          _emailCtrl,
          'Email Address',
          Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _passCtrl,
          'Password',
          Icons.lock_outline,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
        ),

        if (!_isSignUp) ...[
          const SizedBox(height: 12),
          _buildTextField(
            _familyCodeCtrl,
            'Joining a Family? Enter Invite Code (Optional)',
            Icons.vpn_key_outlined,
            keyboardType: TextInputType.text,
          ),
        ],

        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.redBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.red.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppTheme.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : () => _handlePrimaryAuthAction(provider),
            icon: _loading
                ? const SizedBox.shrink()
                : Icon(_isSignUp ? Icons.mark_email_read_outlined : Icons.login_rounded, size: 18),
            label: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                : Text(
                    _isSignUp
                        ? (_joinExistingFamily ? 'Verify Email & Join Family' : 'Create Account & Verify Email')
                        : 'Sign In',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  /// Single clean Email OTP Verification step (never exposes test OTP in UI)
  Widget _buildOtpVerificationStep(FinanceProvider provider) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _awaitingOtpStep = false;
                    _errorMsg = null;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Verify Your Email',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We sent a 6-digit verification code to $_activeIdentifier. Enter or paste the code below to complete your registration.',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '6-Digit Email Verification Code',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _tryAutoReadOtpFromClipboard(silentIfEmpty: false),
                    child: const Row(
                      children: [
                        Icon(Icons.content_paste_go, size: 13, color: AppTheme.accent200),
                        SizedBox(width: 4),
                        Text(
                          'Paste Code',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.accent200, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _resendEmailOtp,
                    child: const Text(
                      'Resend',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.accent100, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildOtpField(
            controller: _loginOtpCtrl,
            hint: 'Enter 6-digit code from email',
            onPastePressed: () => _tryAutoReadOtpFromClipboard(silentIfEmpty: false),
          ),

          if (_autoReadStatusMsg != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: AppTheme.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _autoReadStatusMsg!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.green),
                  ),
                ),
              ],
            ),
          ],

          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.redBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.red.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : () => _verifyAndCompleteAuth(provider),
              icon: _loading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                  : const Text(
                      'Verify Email & Continue',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onPastePressed,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_outlined, size: 18, color: AppTheme.accent200),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              enableInteractiveSelection: true,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
                letterSpacing: 2.0,
              ),
              onChanged: (val) {
                if (val.length > 6) {
                  final extracted = SupabaseService.extractOtpFromText(val);
                  if (extracted != null) {
                    controller.value = TextEditingValue(
                      text: extracted,
                      selection: TextSelection.collapsed(offset: extracted.length),
                    );
                    setState(() {
                      _autoReadStatusMsg = 'Extracted 6-digit code from pasted text';
                      _errorMsg = null;
                    });
                  }
                }
              },
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textSubtle,
                  letterSpacing: 0,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: onPastePressed,
            icon: const Icon(Icons.content_paste_rounded, size: 17, color: AppTheme.accent200),
            tooltip: 'Paste verification code',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscureText = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3F424D)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSubtle),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              enableInteractiveSelection: true,
              style: const TextStyle(fontSize: 14, color: AppTheme.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSubtle),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

